import { Pool } from 'pg';
import { env } from './env';

export const pool = new Pool({
  connectionString: env.databaseUrl,
  // Sized for a small VPS by default; raise it if the box grows.
  max: Number(process.env.PG_POOL_MAX ?? 20),
  idleTimeoutMillis: 30_000,
});

/** Convenience for the common "one row or nothing" query. */
export async function one<T = any>(
  sql: string,
  params: unknown[] = [],
): Promise<T | null> {
  const { rows } = await pool.query(sql, params);
  return (rows[0] as T) ?? null;
}

export async function many<T = any>(
  sql: string,
  params: unknown[] = [],
): Promise<T[]> {
  const { rows } = await pool.query(sql, params);
  return rows as T[];
}
