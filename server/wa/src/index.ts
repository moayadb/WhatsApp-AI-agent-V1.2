import Fastify from 'fastify';

import { pool } from './db';
import { env } from './env';
import { logger } from './logger';
import {
  logoutSession,
  resumeAll,
  snapshot,
  startSession,
  stopSession,
  type LinkMethod,
} from './sessions';

const app = Fastify({ loggerInstance: logger });

/**
 * This service holds live WhatsApp credentials for every linked number, so it
 * is never published through Caddy. The shared token is a second lock in case
 * the compose network is ever mis-configured.
 */
app.addHook('onRequest', async (request, reply) => {
  if (request.url === '/health') return;
  if (request.headers['x-internal-token'] !== env.internalToken) {
    await reply.code(401).send({ error: 'unauthorized' });
  }
});

app.get('/health', async () => {
  await pool.query('SELECT 1');
  return { ok: true };
});

interface StartBody {
  method?: LinkMethod;
  phone?: string;
}

/** Begin linking, or return the state of a link already in progress. */
app.post<{ Params: { channelId: string }; Body: StartBody }>(
  '/sessions/:channelId/start',
  async (request, reply) => {
    const { channelId } = request.params;
    const method = request.body?.method ?? 'pairing_code';
    const phone = request.body?.phone;

    if (method === 'pairing_code' && !phone) {
      return reply
        .code(400)
        .send({ error: 'phone is required for pairing-code linking' });
    }

    try {
      const state = await startSession(channelId, { method, phone });
      return reply.send(state);
    } catch (error) {
      logger.error({ err: error, channelId }, 'failed to start session');
      return reply.code(500).send({ error: (error as Error).message });
    }
  },
);

/** Poll target while the pairing code / QR is on screen. */
app.get<{ Params: { channelId: string } }>(
  '/sessions/:channelId',
  async (request, reply) => {
    const state = snapshot(request.params.channelId);
    if (state) return reply.send(state);

    // Not in memory — report what the database last recorded.
    const { rows } = await pool.query(
      `SELECT id, status, link_method, pairing_code, qr,
              pairing_expires_at, last_error
         FROM channels WHERE id = $1`,
      [request.params.channelId],
    );
    if (rows.length === 0) return reply.code(404).send({ error: 'not found' });

    const row = rows[0];
    return reply.send({
      channel_id: row.id,
      status: row.status,
      link_method: row.link_method,
      pairing_code: row.pairing_code,
      qr: row.qr,
      expires_at: row.pairing_expires_at,
      last_error: row.last_error,
      live: false,
    });
  },
);

/** Pause monitoring without unlinking the device. */
app.post<{ Params: { channelId: string } }>(
  '/sessions/:channelId/stop',
  async (request, reply) => {
    await stopSession(request.params.channelId);
    return reply.send({ ok: true });
  },
);

/** Unlink permanently and destroy the credentials. */
app.post<{ Params: { channelId: string } }>(
  '/sessions/:channelId/logout',
  async (request, reply) => {
    await logoutSession(request.params.channelId);
    return reply.send({ ok: true });
  },
);

/**
 * Resume sessions, retrying until the database is reachable.
 *
 * Boot order is not guaranteed — this service can come up seconds before
 * Postgres does (compose healthchecks narrow the window but restarts and bare-
 * metal runs do not). A resume that fails once and gives up leaves every
 * WhatsApp session silently dead while the channel rows still read
 * "connected": messages simply stop arriving with no error anywhere. That
 * exact failure happened; hence the loop.
 */
async function resumeWithRetry(): Promise<void> {
  const RETRY_MS = 5_000;
  const MAX_ATTEMPTS = 60; // five minutes, then something is truly wrong

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    try {
      await pool.query('SELECT 1');
      await resumeAll();
      return;
    } catch (err) {
      logger.warn(
        { err, attempt, retryInMs: RETRY_MS },
        'resume failed — database not ready yet, retrying',
      );
      await new Promise((resolve) => setTimeout(resolve, RETRY_MS));
    }
  }
  logger.error(
    { attempts: MAX_ATTEMPTS },
    'giving up on session resume — restart this service once the database is up',
  );
}

async function main(): Promise<void> {
  await app.listen({ port: env.port, host: '0.0.0.0' });
  logger.info({ port: env.port }, 'wa service listening');
  // Restart must not cost ten agents a re-link.
  void resumeWithRetry();
}

for (const signal of ['SIGTERM', 'SIGINT'] as const) {
  process.on(signal, () => {
    logger.info({ signal }, 'shutting down');
    app.close().finally(() => pool.end().finally(() => process.exit(0)));
  });
}

main().catch((error) => {
  logger.error({ err: error }, 'fatal');
  process.exit(1);
});
