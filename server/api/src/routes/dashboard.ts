import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { many, one } from '../db';
import { sessionOf } from '../session';

/**
 * The board that replaces "did you follow up?" at the Sunday meeting.
 *
 * Median rather than mean first-response time on purpose: one agent who was
 * asleep for six hours would drag an average far enough to hide nine agents
 * doing fine, which is precisely the failure that started this project.
 */
export default async function dashboardRoutes(
  app: FastifyInstance,
): Promise<void> {
  app.addHook('onRequest', app.authenticate);

  app.get('/dashboard/agents', async (request, reply) => {
    const parsed = z
      .object({ days: z.coerce.number().int().min(1).max(90).default(7) })
      .safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_input' });

    const { orgId } = sessionOf(request);
    return many(
      `WITH window_bounds AS (
         SELECT now() - make_interval(days => $2::int) AS since
       )
       SELECT a.id, a.name,
              -- connection health: a "perfect" agent whose phone unlinked two
              -- days ago is not perfect, they are invisible.
              COALESCE(ch.linked, 0)          AS linked_numbers,
              COALESCE(ch.connected, 0)       AS connected_numbers,
              COALESCE(conv.open_threads, 0)  AS open_threads,
              COALESCE(conv.waiting_now, 0)   AS waiting_now,
              conv.longest_wait_minutes,
              conv.median_first_response_ms,
              COALESCE(al.alerts_total, 0)    AS alerts_total,
              COALESCE(al.alerts_open, 0)     AS alerts_open,
              COALESCE(al.sla_breaches, 0)    AS sla_breaches,
              COALESCE(al.cold_leads, 0)      AS cold_leads,
              COALESCE(al.conduct_flags, 0)   AS conduct_flags
         FROM agents a
         LEFT JOIN (
           SELECT agent_id,
                  count(*) AS linked,
                  count(*) FILTER (WHERE status = 'connected') AS connected
             FROM channels WHERE org_id = $1 GROUP BY agent_id
         ) ch ON ch.agent_id = a.id
         LEFT JOIN (
           SELECT cv.agent_id,
                  count(*) AS open_threads,
                  count(*) FILTER (WHERE cv.awaiting_reply_since IS NOT NULL) AS waiting_now,
                  ROUND(MAX(EXTRACT(EPOCH FROM (now() - cv.awaiting_reply_since)) / 60)) AS longest_wait_minutes,
                  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cv.first_response_ms)
                    FILTER (WHERE cv.first_response_ms IS NOT NULL) AS median_first_response_ms
             FROM conversations cv, window_bounds w
            WHERE cv.org_id = $1 AND cv.last_message_at >= w.since
            GROUP BY cv.agent_id
         ) conv ON conv.agent_id = a.id
         LEFT JOIN (
           SELECT agent_id,
                  count(*) AS alerts_total,
                  count(*) FILTER (WHERE status = 'new') AS alerts_open,
                  count(*) FILTER (WHERE type = 'sla_breach') AS sla_breaches,
                  count(*) FILTER (WHERE type = 'cold_lead') AS cold_leads,
                  count(*) FILTER (WHERE type IN ('unauthorized_promise','off_channel')) AS conduct_flags
             FROM alerts, window_bounds w
            WHERE org_id = $1 AND event_at >= w.since
            GROUP BY agent_id
         ) al ON al.agent_id = a.id
        WHERE a.org_id = $1 AND a.active
        ORDER BY COALESCE(conv.waiting_now, 0) DESC,
                 COALESCE(al.alerts_open, 0) DESC,
                 a.name`,
      [orgId, parsed.data.days],
    );
  });

  /** Headline numbers for the top of the screen. */
  app.get('/dashboard/summary', async (request, reply) => {
    const parsed = z
      .object({ days: z.coerce.number().int().min(1).max(90).default(7) })
      .safeParse(request.query);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_input' });

    const { orgId } = sessionOf(request);
    const days = parsed.data.days;

    const [alerts, conversations, channels] = await Promise.all([
      one(
        `SELECT count(*) AS total,
                count(*) FILTER (WHERE status = 'new') AS open,
                count(*) FILTER (WHERE severity = 'urgent') AS urgent,
                count(*) FILTER (WHERE type = 'sla_breach') AS sla_breaches,
                count(*) FILTER (WHERE type = 'cold_lead') AS cold_leads,
                count(*) FILTER (WHERE type = 'unauthorized_promise') AS unauthorized_promises,
                count(*) FILTER (WHERE type = 'off_channel') AS off_channel,
                PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY handling_ms)
                  FILTER (WHERE handling_ms IS NOT NULL) AS median_handling_ms
           FROM alerts
          WHERE org_id = $1 AND event_at >= now() - make_interval(days => $2::int)`,
        [orgId, days],
      ),
      one(
        `SELECT count(*) AS active_threads,
                count(*) FILTER (WHERE awaiting_reply_since IS NOT NULL) AS waiting_now,
                PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY first_response_ms)
                  FILTER (WHERE first_response_ms IS NOT NULL) AS median_first_response_ms
           FROM conversations
          WHERE org_id = $1 AND last_message_at >= now() - make_interval(days => $2::int)`,
        [orgId, days],
      ),
      one(
        `SELECT count(*) AS total,
                count(*) FILTER (WHERE status = 'connected') AS connected,
                count(*) FILTER (WHERE status IN ('disconnected','logged_out','error')) AS needs_attention
           FROM channels WHERE org_id = $1`,
        [orgId],
      ),
    ]);

    return reply.send({ days, alerts, conversations, channels });
  });
}
