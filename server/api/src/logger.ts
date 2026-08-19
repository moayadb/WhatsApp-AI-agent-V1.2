import pino from 'pino';
import { env } from './env';

export const logger = pino({
  level: env.logLevel,
  // Customer conversation content passes through this service. Anything that
  // could carry a message body is redacted before it reaches a log sink.
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers["x-internal-token"]',
      'req.headers["x-analyzer-secret"]',
      'body.password',
      'body.message.body',
    ],
    remove: true,
  },
});
