import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { one, pool } from '../db';
import { hashPassword, verifyPassword } from '../security';
import { sessionOf } from '../session';

const signupSchema = z.object({
  full_name: z.string().min(2).max(120),
  email: z.string().email().max(200),
  // Journey step 1 asks for a personal number; it is how we reach Faisal, and
  // later how we recognise his own WhatsApp among the linked channels.
  phone_e164: z.string().regex(/^\+[1-9]\d{6,14}$/, 'phone must be E.164, e.g. +9715…'),
  password: z.string().min(8).max(200),
  company_name: z.string().min(2).max(160).optional(),
  timezone: z.string().max(64).optional(),
  locale: z.enum(['ar', 'en']).optional(),
  /** Explicit consent, stored as a timestamp rather than a boolean. */
  accept_terms: z.literal(true),
  accept_privacy: z.literal(true),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export default async function authRoutes(app: FastifyInstance): Promise<void> {
  /**
   * Self-service registration. The first user of an org creates the org, its
   * settings and its (empty) profile in one transaction — replacing the old
   * hand-made Firebase allowlist accounts entirely.
   */
  app.post('/auth/signup', async (request, reply) => {
    const parsed = signupSchema.safeParse(request.body);
    if (!parsed.success) {
      return reply
        .code(400)
        .send({ error: 'invalid_input', details: parsed.error.issues });
    }
    const body = parsed.data;

    const existing = await one('SELECT id FROM users WHERE email = $1', [
      body.email,
    ]);
    if (existing) {
      return reply.code(409).send({ error: 'email_taken' });
    }

    const passwordHash = await hashPassword(body.password);
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const org = await client.query(
        `INSERT INTO orgs (name, locale, timezone)
         VALUES ($1, $2, $3) RETURNING id`,
        [
          body.company_name ?? body.full_name,
          body.locale ?? 'ar',
          body.timezone ?? 'Asia/Dubai',
        ],
      );
      const orgId = org.rows[0].id as string;

      const user = await client.query(
        `INSERT INTO users (org_id, full_name, email, phone_e164, password_hash,
                            role, terms_accepted_at, privacy_accepted_at, last_login_at)
         VALUES ($1,$2,$3,$4,$5,'owner', now(), now(), now())
         RETURNING id, full_name, email, phone_e164, role`,
        [orgId, body.full_name, body.email, body.phone_e164, passwordHash],
      );

      // Defaults exist from the first second so the detectors can run before
      // the user ever opens settings.
      await client.query('INSERT INTO org_settings (org_id) VALUES ($1)', [orgId]);
      await client.query('INSERT INTO org_profiles (org_id) VALUES ($1)', [orgId]);

      await client.query('COMMIT');

      const row = user.rows[0];
      const token = app.jwt.sign({ sub: row.id, org_id: orgId, role: row.role });
      return reply.code(201).send({ token, user: { ...row, org_id: orgId } });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  });

  app.post('/auth/login', async (request, reply) => {
    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) return reply.code(400).send({ error: 'invalid_input' });

    const user = await one<{
      id: string;
      org_id: string;
      full_name: string;
      email: string;
      phone_e164: string;
      role: string;
      password_hash: string;
    }>(
      `SELECT id, org_id, full_name, email, phone_e164, role, password_hash
         FROM users WHERE email = $1`,
      [parsed.data.email],
    );

    // Same response whether the account is missing or the password is wrong —
    // otherwise this endpoint enumerates customers.
    const ok = user
      ? await verifyPassword(parsed.data.password, user.password_hash)
      : false;
    if (!user || !ok) {
      return reply.code(401).send({ error: 'invalid_credentials' });
    }

    await pool.query('UPDATE users SET last_login_at = now() WHERE id = $1', [
      user.id,
    ]);

    const token = app.jwt.sign({
      sub: user.id,
      org_id: user.org_id,
      role: user.role,
    });
    return reply.send({
      token,
      user: {
        id: user.id,
        org_id: user.org_id,
        full_name: user.full_name,
        email: user.email,
        phone_e164: user.phone_e164,
        role: user.role,
      },
    });
  });

  /** Everything the app needs to decide which screen to show on launch. */
  app.get(
    '/me',
    { onRequest: [app.authenticate] },
    async (request) => {
      const { userId, orgId } = sessionOf(request);

      const user = await one(
        `SELECT id, org_id, full_name, email, phone_e164, role
           FROM users WHERE id = $1`,
        [userId],
      );
      const org = await one(
        `SELECT o.id, o.name, o.locale, o.timezone,
                p.completed_at AS onboarding_completed_at,
                (SELECT count(*) FROM agents WHERE org_id = o.id AND active) AS agent_count,
                (SELECT count(*) FROM channels
                  WHERE org_id = o.id AND status = 'connected') AS connected_channels
           FROM orgs o
           LEFT JOIN org_profiles p ON p.org_id = o.id
          WHERE o.id = $1`,
        [orgId],
      );
      const settings = await one(
        'SELECT * FROM org_settings WHERE org_id = $1',
        [orgId],
      );

      return { user, org, settings };
    },
  );

  /** Register this install for push. Replaces the Firestore device_tokens doc. */
  app.post(
    '/devices',
    { onRequest: [app.authenticate] },
    async (request, reply) => {
      const schema = z.object({
        token: z.string().min(10),
        platform: z.enum(['android', 'ios', 'web']),
      });
      const parsed = schema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: 'invalid_input' });

      const { userId } = sessionOf(request);
      await pool.query(
        `INSERT INTO devices (user_id, token, platform)
         VALUES ($1, $2, $3)
         ON CONFLICT (token) DO UPDATE
           SET user_id = EXCLUDED.user_id, updated_at = now()`,
        [userId, parsed.data.token, parsed.data.platform],
      );
      return reply.send({ ok: true });
    },
  );

  app.delete(
    '/devices/:token',
    { onRequest: [app.authenticate] },
    async (request) => {
      const { token } = request.params as { token: string };
      const { userId } = sessionOf(request);
      await pool.query(
        'DELETE FROM devices WHERE token = $1 AND user_id = $2',
        [token, userId],
      );
      return { ok: true };
    },
  );
}
