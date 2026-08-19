import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { many, one, pool } from '../db';
import { logger } from '../logger';
import { broadcast } from '../realtime';
import { sessionOf } from '../session';
import { wa } from '../wa-client';

/**
 * Journey step 3, second half: connect the numbers to monitor.
 *
 * Two ways in, both ending at the same place:
 *   pairing_code — WhatsApp → Linked devices → "Link with phone number
 *                  instead", then type the 8-character code. This is the flow
 *                  that works when the agent is not standing next to you.
 *   qr           — the classic scan, for when they are.
 */

const linkSchema = z.object({
  agent_id: z.string().uuid().nullable().optional(),
  label: z.string().max(120).optional(),
  phone_e164: z
    .string()
    .regex(/^\+[1-9]\d{6,14}$/, 'phone must be E.164, e.g. +9715…')
    .optional(),
  method: z.enum(['pairing_code', 'qr']).default('pairing_code'),
  /** Who agreed to have this number monitored. Kept for the record. */
  consent_name: z.string().max(120).optional(),
});

export default async function channelRoutes(
  app: FastifyInstance,
): Promise<void> {
  app.addHook('onRequest', app.authenticate);

  app.get('/channels', async (request) => {
    const { orgId } = sessionOf(request);
    return many(
      `SELECT c.id, c.label, c.phone_e164, c.wa_jid, c.status, c.link_method,
              c.pairing_code, c.pairing_expires_at, c.last_connected_at,
              c.last_disconnected_at, c.last_error, c.consent_name, c.consent_at,
              c.created_at,
              c.agent_id, a.name AS agent_name,
              (SELECT count(*) FROM conversations cv WHERE cv.channel_id = c.id) AS conversation_count
         FROM channels c
         LEFT JOIN agents a ON a.id = c.agent_id
        WHERE c.org_id = $1
        ORDER BY c.created_at`,
      [orgId],
    );
  });

  /**
   * Start linking a number.
   *
   * Idempotent per phone number: asking twice for the same number returns the
   * code already in flight instead of creating a duplicate channel — the app
   * polls this while the agent looks for their phone.
   */
  app.post('/channels', async (request, reply) => {
    const parsed = linkSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply
        .code(400)
        .send({ error: 'invalid_input', details: parsed.error.issues });
    }
    const body = parsed.data;

    if (body.method === 'pairing_code' && !body.phone_e164) {
      return reply.code(400).send({ error: 'phone_required_for_pairing_code' });
    }

    const { orgId } = sessionOf(request);

    if (body.agent_id) {
      const agent = await one(
        'SELECT id FROM agents WHERE id = $1 AND org_id = $2',
        [body.agent_id, orgId],
      );
      if (!agent) return reply.code(404).send({ error: 'agent_not_found' });
    }

    const channel = await one<{ id: string }>(
      `INSERT INTO channels (org_id, agent_id, label, phone_e164, link_method,
                             status, consent_name, consent_at)
       VALUES ($1,$2,$3,$4,$5,'new',$6, CASE WHEN $6::text IS NULL THEN NULL ELSE now() END)
       ON CONFLICT (org_id, phone_e164) DO UPDATE
         SET agent_id = COALESCE(EXCLUDED.agent_id, channels.agent_id),
             label = COALESCE(EXCLUDED.label, channels.label),
             link_method = EXCLUDED.link_method
       RETURNING id`,
      [
        orgId,
        body.agent_id ?? null,
        body.label ?? null,
        body.phone_e164 ?? null,
        body.method,
        body.consent_name ?? null,
      ],
    );

    if (!channel) return reply.code(500).send({ error: 'channel_not_created' });

    try {
      const state = await wa.start(channel.id, {
        method: body.method,
        phone: body.phone_e164,
      });
      const row = await one(
        `SELECT c.*, a.name AS agent_name
           FROM channels c LEFT JOIN agents a ON a.id = c.agent_id
          WHERE c.id = $1`,
        [channel.id],
      );
      broadcast(orgId, { type: 'channel.status', channel: row });
      return reply.code(201).send({ channel: row, link: state });
    } catch (error) {
      const message = (error as Error).message;
      logger.error({ err: error, channelId: channel.id }, 'link start failed');
      await pool.query(
        `UPDATE channels SET status = 'error', last_error = $2 WHERE id = $1`,
        [channel.id, message],
      );
      return reply
        .code(502)
        .send({ error: 'link_failed', detail: message, channel_id: channel.id });
    }
  });

  /**
   * Poll target while the code is on screen.
   *
   * Reads through to the session service rather than the database so the
   * transition to `connected` shows up the instant WhatsApp accepts the code.
   */
  app.get('/channels/:id/link', async (request, reply) => {
    const { id } = request.params as { id: string };
    const { orgId } = sessionOf(request);

    const owned = await one('SELECT id FROM channels WHERE id = $1 AND org_id = $2', [
      id,
      orgId,
    ]);
    if (!owned) return reply.code(404).send({ error: 'not_found' });

    try {
      return reply.send(await wa.status(id));
    } catch (error) {
      logger.warn({ err: error, channelId: id }, 'wa status unavailable');
      const row = await one(
        `SELECT id AS channel_id, status, link_method, pairing_code, qr,
                pairing_expires_at AS expires_at, last_error
           FROM channels WHERE id = $1`,
        [id],
      );
      return reply.send({ ...row, live: false });
    }
  });

  /** Ask for a fresh code — the previous one expires after about a minute. */
  app.post('/channels/:id/relink', async (request, reply) => {
    const { id } = request.params as { id: string };
    const { orgId } = sessionOf(request);

    const channel = await one<{ phone_e164: string | null }>(
      'SELECT phone_e164 FROM channels WHERE id = $1 AND org_id = $2',
      [id, orgId],
    );
    if (!channel) return reply.code(404).send({ error: 'not_found' });

    const parsed = z
      .object({
        method: z.enum(['pairing_code', 'qr']).default('pairing_code'),
        phone_e164: z.string().regex(/^\+[1-9]\d{6,14}$/).optional(),
      })
      .safeParse(request.body ?? {});
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_input' });

    const phone = parsed.data.phone_e164 ?? channel.phone_e164 ?? undefined;
    if (parsed.data.method === 'pairing_code' && !phone) {
      return reply.code(400).send({ error: 'phone_required_for_pairing_code' });
    }

    // Drop whatever socket is open first: a stale one would keep answering
    // with the expired code.
    await wa.stop(id).catch(() => undefined);
    const state = await wa.start(id, { method: parsed.data.method, phone });
    return reply.send(state);
  });

  app.patch('/channels/:id', async (request, reply) => {
    const schema = z.object({
      agent_id: z.string().uuid().nullable().optional(),
      label: z.string().max(120).nullable().optional(),
    });
    const parsed = schema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_input' });

    const entries = Object.entries(parsed.data);
    if (entries.length === 0) return reply.code(400).send({ error: 'empty' });

    const { id } = request.params as { id: string };
    const { orgId } = sessionOf(request);
    const sets = entries.map(([key], i) => `${key} = $${i + 3}`).join(', ');
    const { rows } = await pool.query(
      `UPDATE channels SET ${sets} WHERE id = $1 AND org_id = $2 RETURNING *`,
      [id, orgId, ...entries.map(([, value]) => value)],
    );
    if (rows.length === 0) return reply.code(404).send({ error: 'not_found' });

    // Re-point existing threads at the new owner so the agent board stays honest.
    if ('agent_id' in parsed.data) {
      await pool.query(
        'UPDATE conversations SET agent_id = $2 WHERE channel_id = $1',
        [id, parsed.data.agent_id ?? null],
      );
    }
    return reply.send(rows[0]);
  });

  /** Unlink the device from WhatsApp but keep the history. */
  app.post('/channels/:id/logout', async (request, reply) => {
    const { id } = request.params as { id: string };
    const { orgId } = sessionOf(request);
    const owned = await one('SELECT id FROM channels WHERE id = $1 AND org_id = $2', [
      id,
      orgId,
    ]);
    if (!owned) return reply.code(404).send({ error: 'not_found' });

    await wa.logout(id).catch((error) =>
      logger.warn({ err: error, channelId: id }, 'wa logout failed'),
    );
    return reply.send({ ok: true });
  });

  app.delete('/channels/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const { orgId } = sessionOf(request);
    const owned = await one('SELECT id FROM channels WHERE id = $1 AND org_id = $2', [
      id,
      orgId,
    ]);
    if (!owned) return reply.code(404).send({ error: 'not_found' });

    await wa.logout(id).catch(() => undefined);
    await pool.query('DELETE FROM channels WHERE id = $1 AND org_id = $2', [
      id,
      orgId,
    ]);
    return reply.send({ ok: true });
  });
}
