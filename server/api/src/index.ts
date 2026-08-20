import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import rateLimit from '@fastify/rate-limit';
import websocket from '@fastify/websocket';
import Fastify from 'fastify';
import type { FastifyReply, FastifyRequest } from 'fastify';

import { pool } from './db';
import { env } from './env';
import { logger } from './logger';
import { migrate } from './migrate';
import { pushConfigured } from './push';
import { addClient, removeClient } from './realtime';
import agentRoutes from './routes/agents';
import alertRoutes from './routes/alerts';
import authRoutes from './routes/auth';
import channelRoutes from './routes/channels';
import dashboardRoutes from './routes/dashboard';
import hookRoutes from './routes/hooks';
import onboardingRoutes from './routes/onboarding';
import { startWorker } from './worker';

declare module 'fastify' {
  interface FastifyInstance {
    authenticate: (
      request: FastifyRequest,
      reply: FastifyReply,
    ) => Promise<void>;
  }
}

const app = Fastify({
  loggerInstance: logger,
  // Caddy terminates TLS and sets X-Forwarded-*; without this every client
  // looks like it came from the proxy, which breaks rate limiting.
  trustProxy: true,
});

async function build(): Promise<void> {
  // The Flutter web build is served from the same origin in production, so CORS
  // matters only for `flutter run -d chrome` against a deployed API.
  await app.register(cors, {
    origin: env.isProduction ? true : true,
    credentials: true,
  });

  await app.register(rateLimit, {
    max: 300,
    timeWindow: '1 minute',
    // Signup and login are the endpoints worth brute-forcing; they get their
    // own tighter limit below.
    allowList: () => false,
  });

  await app.register(jwt, {
    secret: env.jwtSecret,
    sign: { expiresIn: '30d' },
  });

  await app.register(websocket);

  app.decorate(
    'authenticate',
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        await request.jwtVerify();
      } catch {
        await reply.code(401).send({ error: 'unauthorized' });
      }
    },
  );

  app.get('/api/health', async () => {
    await pool.query('SELECT 1');
    return { ok: true };
  });

  await app.register(
    async (instance) => {
      await instance.register(rateLimit, { max: 20, timeWindow: '1 minute' });
      await authRoutes(instance);
    },
    { prefix: '/api' },
  );

  await app.register(onboardingRoutes, { prefix: '/api' });
  await app.register(agentRoutes, { prefix: '/api' });
  await app.register(channelRoutes, { prefix: '/api' });
  await app.register(alertRoutes, { prefix: '/api' });
  await app.register(dashboardRoutes, { prefix: '/api' });
  await app.register(hookRoutes, { prefix: '/api' });

  /**
   * Live feed. The token travels as a query parameter because browsers cannot
   * set headers on a WebSocket handshake; it is verified before the socket is
   * added to any org's fan-out set.
   */
  app.get('/ws', { websocket: true }, async (socket, request) => {
    const token = (request.query as { token?: string })?.token;
    if (!token) {
      socket.close(4401, 'unauthorized');
      return;
    }

    let orgId: string;
    try {
      const payload = app.jwt.verify<{ org_id: string }>(token);
      orgId = payload.org_id;
    } catch {
      socket.close(4401, 'unauthorized');
      return;
    }

    addClient(orgId, socket as never);
    socket.send(JSON.stringify({ type: 'ready' }));
    socket.on('close', () => removeClient(orgId, socket as never));
    socket.on('error', () => removeClient(orgId, socket as never));
  });
}

async function main(): Promise<void> {
  await migrate();
  await build();
  await app.listen({ port: env.port, host: '0.0.0.0' });
  logger.info({ port: env.port }, 'api listening');
  // Says out loud which deployment this is. Silence from a push-less box is
  // indistinguishable from silence from a broken one.
  logger.info(
    { push: pushConfigured() ? 'enabled' : 'disabled' },
    pushConfigured()
      ? 'push notifications configured'
      : 'push disabled: no FCM service account configured',
  );
  startWorker();
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
