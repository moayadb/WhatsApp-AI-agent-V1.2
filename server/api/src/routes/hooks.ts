import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { createAlert } from '../alerts';
import { one, pool } from '../db';
import { env } from '../env';
import { secretEquals } from '../security';

/**
 * The n8n callback surface.
 *
 * n8n reads a message plus its thread, asks the model whether a human needs to
 * step in, and posts the verdict back here. It is a separate machine on the
 * public internet, so it authenticates with a shared secret and is trusted for
 * exactly two things: raising an alert, and attaching a voice-note transcript.
 */

const verdictSchema = z.object({
  org_id: z.string().uuid(),
  conversation_id: z.string().uuid().optional(),
  channel_id: z.string().uuid().optional(),
  agent_id: z.string().uuid().nullable().optional(),
  contact_id: z.string().uuid().optional(),
  /** `false` is the normal answer — most messages are unremarkable. */
  needs_attention: z.boolean(),
  type: z
    .enum([
      'sla_breach',
      'cold_lead',
      'unauthorized_promise',
      'off_channel',
      'escalation',
      'other',
    ])
    .default('other'),
  severity: z.enum(['urgent', 'high', 'medium', 'low']).default('medium'),
  title: z.string().min(1).max(300),
  insight: z.string().max(2000).optional(),
  recommended_action: z.string().max(1000).optional(),
  evidence: z.unknown().optional(),
  event_at: z.coerce.date().optional(),
  message_id: z.string().uuid().optional(),
});

export default async function hookRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('onRequest', async (request, reply) => {
    if (!secretEquals(request.headers['x-analyzer-secret'] as string, env.n8nSecret)) {
      await reply.code(401).send({ error: 'unauthorized' });
    }
  });

  app.post('/hooks/n8n/alert', async (request, reply) => {
    const parsed = verdictSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply
        .code(400)
        .send({ error: 'invalid_input', details: parsed.error.issues });
    }
    const body = parsed.data;

    // The model saying "nothing to see here" is a successful call, not an error.
    if (!body.needs_attention) return reply.send({ ok: true, created: false });

    const org = await one('SELECT id FROM orgs WHERE id = $1', [body.org_id]);
    if (!org) return reply.code(404).send({ error: 'org_not_found' });

    // Attribution is the entire product: an alert nobody owns cannot appear on
    // the agent board and cannot answer "who let this happen". n8n is expected
    // to echo the ids it was given, but a workflow edit that drops one must not
    // silently produce orphan alerts — so anything missing is derived from the
    // conversation, which already knows its channel, agent and contact.
    let { channel_id: channelId, agent_id: agentId, contact_id: contactId } = body;
    if (body.conversation_id) {
      const conversation = await one<{
        org_id: string;
        channel_id: string;
        agent_id: string | null;
        contact_id: string;
      }>(
        'SELECT org_id, channel_id, agent_id, contact_id FROM conversations WHERE id = $1',
        [body.conversation_id],
      );
      if (!conversation) {
        return reply.code(404).send({ error: 'conversation_not_found' });
      }
      // n8n holds one secret for every tenant, so the org it claims must match
      // the org that actually owns the thread.
      if (conversation.org_id !== body.org_id) {
        return reply.code(403).send({ error: 'org_mismatch' });
      }
      channelId ??= conversation.channel_id;
      agentId ??= conversation.agent_id;
      contactId ??= conversation.contact_id;
    }

    // A verdict about one specific message should never produce two alerts,
    // however many times n8n retries the webhook.
    const dedupeKey = body.message_id
      ? `ai:${body.message_id}:${body.type}`
      : null;

    const alert = await createAlert({
      orgId: body.org_id,
      conversationId: body.conversation_id ?? null,
      channelId: channelId ?? null,
      agentId: agentId ?? null,
      contactId: contactId ?? null,
      type: body.type,
      severity: body.severity,
      title: body.title,
      insight: body.insight ?? null,
      recommendedAction: body.recommended_action ?? null,
      evidence: body.evidence ?? [],
      eventAt: body.event_at ?? new Date(),
      dedupeKey,
    });

    return reply.send({ ok: true, created: Boolean(alert), alert });
  });

  /** Voice notes come back from n8n as text once transcribed. */
  app.post('/hooks/n8n/transcript', async (request, reply) => {
    const parsed = z
      .object({
        message_id: z.string().uuid(),
        transcript: z.string().max(20_000),
      })
      .safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_input' });

    const { rowCount } = await pool.query(
      'UPDATE messages SET transcript = $2 WHERE id = $1',
      [parsed.data.message_id, parsed.data.transcript],
    );
    if (rowCount === 0) return reply.code(404).send({ error: 'not_found' });
    return reply.send({ ok: true });
  });
}
