import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';

import { pool } from './db';
import { logger } from './logger';

// In the image the migrations sit next to the build output. Overridable so the
// API can also be run straight from source during development.
const MIGRATIONS_DIR =
  process.env.MIGRATIONS_DIR ?? path.resolve(__dirname, '..', 'db', 'migrations');

/**
 * Apply any `.sql` file in db/migrations that has not run yet, in filename
 * order, each in its own transaction.
 *
 * Deliberately not using Postgres' `docker-entrypoint-initdb.d`: that only
 * fires on a brand-new data volume, so the second migration would never run on
 * an existing deployment.
 */
export async function migrate(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name        text PRIMARY KEY,
      applied_at  timestamptz NOT NULL DEFAULT now()
    )
  `);

  const files = (await readdir(MIGRATIONS_DIR))
    .filter((name) => name.endsWith('.sql'))
    .sort();

  const { rows } = await pool.query('SELECT name FROM schema_migrations');
  const applied = new Set(rows.map((row) => row.name as string));

  for (const file of files) {
    if (applied.has(file)) continue;

    const sql = await readFile(path.join(MIGRATIONS_DIR, file), 'utf8');
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [
        file,
      ]);
      await client.query('COMMIT');
      logger.info({ migration: file }, 'migration applied');
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error({ err: error, migration: file }, 'migration failed');
      throw error;
    } finally {
      client.release();
    }
  }
}
