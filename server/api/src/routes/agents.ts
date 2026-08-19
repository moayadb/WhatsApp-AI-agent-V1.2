import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { many, one, pool } from '../db';
import { sessionOf } from '../session';

/**
 * Journey step 3, first half: Faisal adds his ten agents by name. Numbers come
 * afterwards, in /channels — an agent exists before any device is linked, and
 * keeps existing if that device is later unlinked.
 */
export default async function agentRoutes(app: FastifyInstance): Promise<void> {
  app.addHook('onRequest', app.authenticate);

  app.get('/agents', async (request) => {
    const { orgId } = sessionOf(request);
    return many(
      `SELECT a.id, a.name, a.email, a.active, a.created_at,
              COALESCE(
                json_agg(
                  json_build_object('id', c.id, 'phone_e164', c.phone_e164,
                                    'status', c.status, 'label', c.label)
                  ORDER BY c.created_at
                ) FILTER (WHERE c.id IS NOT NULL),
                '[]'
              ) AS channels
         FROM agents a
         LEFT JOIN channels c ON c.agent_id = a.id
        WHERE a.org_id = $1
        GROUP BY a.id
        ORDER BY a.created_at`,
      [orgId],
    );
  });

  app.post('/agents', async (request, reply) => {
    const schema = z.object({
      name: z.string().min(1).max(120),
      email: z.string().email().max(200).optional(),
    });
    const parsed = schema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_input' });

    const { orgId } = sessionOf(request);
    const row = await one(
      `INSERT INTO agents (org_id, name, email) VALUES ($1, $2, $3)
       RETURNING id, name, email, active, created_at`,
      [orgId, parsed.data.name, parsed.data.email ?? null],
    );
    return reply.code(201).send(row);
  });

  /** Add the whole team in one go — ten names pasted at once. */
  app.post('/agents/bulk', async (request, reply) => {
    const schema = z.object({
      names: z.array(z.string().min(1).max(120)).min(1).max(100),
    });
    const parsed = schema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_input' });

    const { orgId } = sessionOf(request);
    const rows = await many(
      `INSERT INTO agents (org_id, name)
       SELECT $1, unnest($2::text[])
       RETURNING id, name, email, active, created_at`,
      [orgId, parsed.data.names],
    );
    return reply.code(201).send(rows);
  });

  app.patch('/agents/:id', async (request, reply) => {
    const schema = z.object({
      name: z.string().min(1).max(120).optional(),
      email: z.string().email().max(200).nullable().optional(),
      active: z.boolean().optional(),
    });
    const parsed = schema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_input' });

    const entries = Object.entries(parsed.data);
    if (entries.length === 0) return reply.code(400).send({ error: 'empty' });

    const { id } = request.params as { id: string };
    const { orgId } = sessionOf(request);
    const sets = entries.map(([key], i) => `${key} = $${i + 3}`).join(', ');
    const { rows } = await pool.query(
      `UPDATE agents SET ${sets} WHERE id = $1 AND org_id = $2
       RETURNING id, name, email, active, created_at`,
      [id, orgId, ...entries.map(([, value]) => value)],
    );
    if (rows.length === 0) return reply.code(404).send({ error: 'not_found' });
    return reply.send(rows[0]);
  });

  /**
   * Deactivate rather than delete: an agent's past alerts are the performance
   * record, and deleting the row would take the history with it.
   */
  app.delete('/agents/:id', async (request, reply) => {
    const { id } = request.params as { id: string };
    const { orgId } = sessionOf(request);
    const { rowCount } = await pool.query(
      'UPDATE agents SET active = false WHERE id = $1 AND org_id = $2',
      [id, orgId],
    );
    if (rowCount === 0) return reply.code(404).send({ error: 'not_found' });
    return reply.send({ ok: true });
  });
}
