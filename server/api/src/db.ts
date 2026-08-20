import { Pool, types } from 'pg';
import { env } from './env';

/**
 * `bigint` comes back as a string, and that string reached the app.
 *
 * node-postgres refuses to narrow int8 by default, because a value above
 * 2^53 would lose precision silently. The consequence here was worse than the
 * problem: `alerts.handling_ms` serialized as `"handling_ms": "21494707"`, the
 * Flutter client cast it with `as num?`, and every handled alert threw a
 * TypeError — one bad row took down the whole feed.
 *
 * Every int8 this schema stores is a duration in milliseconds or a row count.
 * `Number.MAX_SAFE_INTEGER` is ~285,000 years in milliseconds, so the
 * precision this gives up does not exist in practice. Registered once, at
 * module load, before any pool is used — so it also covers int8 columns nobody
 * has added yet.
 */
types.setTypeParser(20, (value) => (value === null ? null : Number(value)));

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
