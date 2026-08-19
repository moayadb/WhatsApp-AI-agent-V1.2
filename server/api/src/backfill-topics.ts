import { pool } from './db';
import { logger } from './logger';
import { backfillTopics } from './prompt';

/**
 * One-shot: give topics to every org that has a monitoring prompt but no
 * labels describing it — orgs onboarded before the topics existed.
 *
 *   node dist/backfill-topics.js
 *
 * with the same environment the API runs on (DATABASE_URL, N8N_INTAKE_URL,
 * N8N_WEBHOOK_SECRET or LLM_API_KEY). Safe to run repeatedly: it only touches
 * rows that still have none, so a re-run after a model outage picks up exactly
 * what was missed.
 */
async function main(): Promise<void> {
  const result = await backfillTopics();
  logger.info(result, 'topics backfill complete');
  // Printed as well as logged: this is run by a person watching a terminal.
  process.stdout.write(`${JSON.stringify(result)}\n`);
  await pool.end();
}

main().catch((error) => {
  logger.error({ err: error }, 'topics backfill failed');
  process.exit(1);
});
