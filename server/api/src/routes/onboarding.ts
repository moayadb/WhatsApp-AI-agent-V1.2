import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { one, pool } from '../db';
import { env } from '../env';
import {
  nextTurn,
  openingQuestion,
  type IntakeTurn,
  type RefineContext,
} from '../intake';
import { llmConfigured } from '../llm';
import { sessionOf } from '../session';

/** Whether any real interviewer (n8n workflow or direct model) is wired up. */
const aiEnabled = () => llmConfigured() || env.n8nIntakeUrl.length > 0;

/**
 * Journey step 2 — the intake conversation.
 *
 * The transcript lives in `org_profiles.transcript`, and its product is
 * `generated_prompt`: the monitoring instructions written for this specific
 * business, which the analysis agent then follows. Everything here exists to
 * get to that prompt and show it to the manager.
 */

const localeSchema = z.enum(['ar', 'en']).default('ar');

async function loadProfile(orgId: string) {
  return one<{
    transcript: IntakeTurn[];
    generated_prompt: string | null;
    prompt_source: string | null;
    completed_at: Date | null;
  }>(
    `SELECT transcript, generated_prompt, prompt_source, completed_at
       FROM org_profiles WHERE org_id = $1`,
    [orgId],
  );
}

export default async function onboardingRoutes(
  app: FastifyInstance,
): Promise<void> {
  app.get('/onboarding', { onRequest: [app.authenticate] }, async (request) => {
    const { orgId } = sessionOf(request);
    const parsed = localeSchema.safeParse(
      (request.query as { locale?: string })?.locale,
    );
    const locale = parsed.success ? parsed.data : 'ar';

    const profile = await loadProfile(orgId);
    const transcript = profile?.transcript ?? [];

    // Nothing said yet: open with the first question so the screen has content
    // immediately and the model is not billed for a greeting.
    if (transcript.length === 0) {
      const opening: IntakeTurn[] = [
        { role: 'assistant', text: openingQuestion(locale) },
      ];
      await pool.query(
        'UPDATE org_profiles SET transcript = $2::jsonb WHERE org_id = $1',
        [orgId, JSON.stringify(opening)],
      );
      return {
        transcript: opening,
        done: false,
        generated_prompt: null,
        ai_enabled: aiEnabled(),
      };
    }

    return {
      transcript,
      done: Boolean(profile?.completed_at),
      generated_prompt: profile?.generated_prompt ?? null,
      prompt_source: profile?.prompt_source ?? null,
      ai_enabled: aiEnabled(),
    };
  });

  app.post(
    '/onboarding/message',
    { onRequest: [app.authenticate] },
    async (request, reply) => {
      const parsed = z
        .object({
          text: z.string().min(1).max(4000),
          locale: localeSchema,
        })
        .safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: 'invalid_input' });

      const { orgId } = sessionOf(request);
      const { text, locale } = parsed.data;

      const profile = await loadProfile(orgId);

      // A finished onboarding does not close the conversation: from then on,
      // every message is a change request against the current monitoring
      // prompt ("also alert me when…", "stop flagging…"). This is the
      // conversational half of prompt editing; Settings has the manual half.
      const refine: RefineContext | undefined =
        profile?.completed_at && profile.generated_prompt
          ? { currentPrompt: profile.generated_prompt }
          : undefined;

      const transcript: IntakeTurn[] = [
        ...(profile?.transcript ?? []),
        { role: 'user', text: text.trim() },
      ];

      const turn = await nextTurn(transcript, locale, refine);
      transcript.push({ role: 'assistant', text: turn.reply });

      await pool.query(
        `UPDATE org_profiles SET transcript = $2::jsonb, updated_at = now()
          WHERE org_id = $1`,
        [orgId, JSON.stringify(transcript)],
      );

      if (turn.done) {
        if (refine) {
          // Only overwrite when the model actually produced an updated prompt;
          // a refine turn that changed nothing must not blank the existing one.
          if (turn.generatedPrompt) {
            await pool.query(
              `UPDATE org_profiles SET
                 generated_prompt = $2,
                 prompt_source = $3,
                 prompt_updated_at = now(),
                 updated_at = now()
               WHERE org_id = $1`,
              [orgId, turn.generatedPrompt, turn.source],
            );
          }
        } else {
          await pool.query(
            `UPDATE org_profiles SET
               generated_prompt = $2,
               prompt_source = $3,
               prompt_updated_at = now(),
               completed_at = now(),
               updated_at = now()
             WHERE org_id = $1`,
            [orgId, turn.generatedPrompt, turn.source],
          );
        }

        // Only write thresholds the interview actually established. A model
        // that stayed silent on a number must not quietly reset it.
        //
        // Enforced in CODE, not just in the prompt: a threshold number is only
        // accepted if the manager literally typed it in some message. Prompt
        // instructions lose against "خسرنا عميلاً بعد ست ساعات… جهز النظام" —
        // the model infers 360 minutes from the failure story, which is
        // usually the OPPOSITE of what the manager wants. Numbers the manager
        // never wrote do not become settings.
        const statedNumbers = new Set<number>();
        for (const t of transcript) {
          if (t.role !== 'user') continue;
          const normalized = t.text.replace(/[٠-٩]/g, (d) =>
            String(d.charCodeAt(0) - 0x0660),
          );
          for (const m of normalized.matchAll(/\d{1,4}/g)) {
            statedNumbers.add(Number(m[0]));
          }
        }
        const stated = (v: unknown): v is number =>
          typeof v === 'number' && statedNumbers.has(Math.round(v));

        const patch: Record<string, unknown> = {};
        const t = {
          ...turn.thresholds,
          first_response_minutes: stated(turn.thresholds.first_response_minutes)
            ? turn.thresholds.first_response_minutes
            : undefined,
          cold_lead_hours: stated(turn.thresholds.cold_lead_hours)
            ? turn.thresholds.cold_lead_hours
            : undefined,
        };
        if (typeof t.first_response_minutes === 'number') {
          patch.first_response_minutes = Math.min(
            1440,
            Math.max(1, Math.round(t.first_response_minutes)),
          );
          patch.vip_first_response_minutes = Math.max(
            1,
            Math.round(patch.first_response_minutes as number / 3),
          );
        }
        if (typeof t.cold_lead_hours === 'number') {
          patch.cold_lead_hours = Math.min(
            720,
            Math.max(1, Math.round(t.cold_lead_hours)),
          );
        }
        if (typeof t.detect_unauthorized_promise === 'boolean') {
          patch.detect_unauthorized_promise = t.detect_unauthorized_promise;
        }
        if (typeof t.detect_off_channel === 'boolean') {
          patch.detect_off_channel = t.detect_off_channel;
        }

        const entries = Object.entries(patch);
        if (entries.length > 0) {
          const sets = entries.map(([key], i) => `${key} = $${i + 2}`).join(', ');
          await pool.query(
            `UPDATE org_settings SET ${sets}, updated_at = now() WHERE org_id = $1`,
            [orgId, ...entries.map(([, value]) => value)],
          );
        }
      }

      const settings = turn.done
        ? await one('SELECT * FROM org_settings WHERE org_id = $1', [orgId])
        : null;

      return reply.send({
        reply: turn.reply,
        // Once onboarding has completed it stays completed: a refine turn that
        // asks a clarifying question must not flip the app back into
        // interview mode.
        done: refine ? true : turn.done,
        generated_prompt: turn.generatedPrompt,
        prompt_source: turn.source,
        transcript,
        settings,
      });
    },
  );

  /**
   * The manager can rewrite the monitoring prompt afterwards. It is the thing
   * that decides what gets flagged, so it must not be frozen at signup.
   */
  app.patch(
    '/onboarding/prompt',
    { onRequest: [app.authenticate] },
    async (request, reply) => {
      const parsed = z
        .object({ generated_prompt: z.string().min(20).max(8000) })
        .safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: 'invalid_input' });

      const { orgId } = sessionOf(request);
      const { rows } = await pool.query(
        `UPDATE org_profiles SET generated_prompt = $2, prompt_source = 'manual',
                                 prompt_updated_at = now(), updated_at = now()
          WHERE org_id = $1
        RETURNING generated_prompt, prompt_source`,
        [orgId, parsed.data.generated_prompt],
      );
      if (rows.length === 0) return reply.code(404).send({ error: 'not_found' });
      return reply.send(rows[0]);
    },
  );

  app.patch(
    '/settings',
    { onRequest: [app.authenticate] },
    async (request, reply) => {
      const schema = z.object({
        first_response_minutes: z.number().int().min(1).max(1440).optional(),
        vip_first_response_minutes: z.number().int().min(1).max(1440).optional(),
        cold_lead_hours: z.number().int().min(1).max(720).optional(),
        quiet_hours_start: z.number().int().min(0).max(23).nullable().optional(),
        quiet_hours_end: z.number().int().min(0).max(23).nullable().optional(),
        detect_unauthorized_promise: z.boolean().optional(),
        detect_off_channel: z.boolean().optional(),
        min_push_severity: z.enum(['urgent', 'high', 'medium', 'low']).optional(),
      });
      const parsed = schema.safeParse(request.body);
      if (!parsed.success) {
        return reply
          .code(400)
          .send({ error: 'invalid_input', details: parsed.error.issues });
      }

      const entries = Object.entries(parsed.data);
      if (entries.length === 0) return reply.code(400).send({ error: 'empty' });

      const { orgId } = sessionOf(request);
      const sets = entries.map(([key], i) => `${key} = $${i + 2}`).join(', ');
      const { rows } = await pool.query(
        `UPDATE org_settings SET ${sets}, updated_at = now()
          WHERE org_id = $1 RETURNING *`,
        [orgId, ...entries.map(([, value]) => value)],
      );
      return reply.send(rows[0]);
    },
  );
}
