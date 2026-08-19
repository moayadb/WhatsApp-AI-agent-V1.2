import pino from 'pino';
import { env } from './env';

export const logger = pino({ level: env.logLevel });

/**
 * Baileys is extremely chatty at debug level and logs message contents.
 * Customer conversations must not end up in container logs, so its logger is
 * pinned to `warn` regardless of ours.
 */
export const baileysLogger = pino({ level: 'warn' });
