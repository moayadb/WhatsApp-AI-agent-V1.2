import { Pool } from 'pg';
import { env } from './env';

export const pool = new Pool({
  connectionString: env.databaseUrl,
  max: 10,
  idleTimeoutMillis: 30_000,
});

export type ChannelStatus =
  | 'new'
  | 'pairing'
  | 'connected'
  | 'syncing'
  | 'disconnected'
  | 'logged_out'
  | 'error';

/** Patch a channel row. Only the keys present are written. */
export async function updateChannel(
  channelId: string,
  patch: Record<string, unknown>,
): Promise<void> {
  const keys = Object.keys(patch);
  if (keys.length === 0) return;
  const sets = keys.map((k, i) => `${k} = $${i + 2}`).join(', ');
  await pool.query(`UPDATE channels SET ${sets} WHERE id = $1`, [
    channelId,
    ...keys.map((k) => patch[k]),
  ]);
}
