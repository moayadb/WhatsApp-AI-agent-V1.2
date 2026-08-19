import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { ALERT_SELECT } from '../alerts';
import { many, one, pool } from '../db';
import { broadcast } from '../realtime';
import { sessionOf } from '../session';

/**
 * Journey step 4 — the notification list.
 *
 * Every row answers the same four questions: which client, which agent, when,
 * and what the AI made of it.
 */
export default async function alertRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('onRequest', app.authenticate);

  app.get('/alerts', async (request, reply) => {
    const schema = z.object({
      status: z.enum(['new', 'done', 'ignored']).optional(),
      type: z
        .enum([
          'sla_breach',
          'cold_lead',
          'unauthorized_promise',
          'off_channel',
          'escalation',
          'other',
        ])
        .optional(),
      severity: z.enum(['urgent', 'high', 'medium', 'low']).optional(),
      agent_id: z.string().uuid().optional(),
      /** Keyset pagination: pass the `event_at` of the last row you have. */
      before: z.coerce.date().optional(),
      limit: z.coerce.number().int().min(1).max(200).default(50),
    });
    const parsed = schema.safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_input' });

    const { orgId } = sessionOf(request);
    const filters: string[] = ['a.org_id = $1'];
    const params: unknown[] = [orgId];

    for (const [column, value] of [
      ['a.status', parsed.data.status],
      ['a.type', parsed.data.type],
      ['a.severity', parsed.data.severity],
      ['a.agent_id', parsed.data.agent_id],
    ] as const) {
      if (value !== undefined) {
        params.push(value);
        filters.push(`${column} = $${params.length}`);
      }
    }
    if (parsed.data.before) {
      params.push(parsed.data.before);
      filters.push(`a.event_at < $${params.length}`);
    }
    params.push(parsed.data.limit);

    return many(
      `${ALERT_SELECT}
        WHERE ${filters.join(' AND ')}
        ORDER BY a.event_at DESC
        LIMIT $${params.length}`,
      params,
    );
  });

  /** Detail view: the alert plus the messages that produced it. */
  app.get('/alerts/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const { orgId } = sessionOf(request);

    const alert = await one(`${ALERT_SELECT} WHERE a.id = $1 AND a.org_id = $2`, [
      id,
      orgId,
    ]);
    if (!alert) return reply.code(404).send({ error: 'not_found' });

    const thread = alert.conversation_id
      ? await many(
          `SELECT direction, body, media_type, transcript, sent_at
             FROM messages
            WHERE conversation_id = $1
            ORDER BY sent_at DESC
            LIMIT 30`,
          [alert.conversation_id],
        )
      : [];

    return reply.send({ ...alert, thread: thread.reverse() });
  });

  /**
   * Triage. `handling_ms` is stamped on the way to `done`, which is what makes
   * "how long did my manager take to intervene" measurable later.
   */
  app.patch('/alerts/:id', async (request, reply) => {
    const parsed = z
      .object({ status: z.enum(['new', 'done', 'ignored']) })
      .safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_input' });

    const { id } = request.params as { id: string };
    const { orgId, userId } = sessionOf(request);
    const done = parsed.data.status === 'done';

    const { rowCount } = await pool.query(
      `UPDATE alerts SET
         status = $3,
         completed_at = CASE WHEN $4 THEN now() ELSE NULL END,
         completed_by = CASE WHEN $4 THEN $5::uuid ELSE NULL END,
         handling_ms = CASE WHEN $4
           THEN (EXTRACT(EPOCH FROM (now() - created_at)) * 1000)::bigint
           ELSE NULL END
       WHERE id = $1 AND org_id = $2`,
      [id, orgId, parsed.data.status, done, userId],
    );
    if (rowCount === 0) return reply.code(404).send({ error: 'not_found' });

    const alert = await one(`${ALERT_SELECT} WHERE a.id = $1`, [id]);
    broadcast(orgId, { type: 'alert.updated', alert });
    return reply.send(alert);
  });
}
