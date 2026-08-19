import { initAuthCreds, BufferJSON, proto } from 'baileys';
import type {
  AuthenticationCreds,
  AuthenticationState,
  SignalDataTypeMap,
} from 'baileys';
import type { Pool } from 'pg';

/**
 * Baileys credential store backed by Postgres — the drop-in replacement for
 * `useMultiFileAuthState`.
 *
 * Why not files: ten agents' sessions on a container filesystem are one
 * `docker compose down -v` away from every one of them having to re-link their
 * phone. Credentials belong in the database that already gets backed up.
 *
 * Buffers are the catch. Signal keys are raw `Buffer`s, which JSON cannot
 * represent, so everything goes through Baileys' own `BufferJSON` replacer on
 * the way in and reviver on the way out.
 */
export async function usePostgresAuthState(
  pool: Pool,
  channelId: string,
): Promise<{
  state: AuthenticationState;
  saveCreds: () => Promise<void>;
  clear: () => Promise<void>;
}> {
  const readData = async (key: string): Promise<any | null> => {
    const { rows } = await pool.query(
      'SELECT value FROM wa_auth_state WHERE channel_id = $1 AND key = $2',
      [channelId, key],
    );
    if (rows.length === 0) return null;
    // pg hands back jsonb already parsed, so re-serialise to run the reviver
    // that turns `{type:'Buffer',data:[...]}` back into real Buffers.
    return JSON.parse(JSON.stringify(rows[0].value), BufferJSON.reviver);
  };

  const writeData = async (key: string, value: unknown): Promise<void> => {
    const encoded = JSON.parse(JSON.stringify(value, BufferJSON.replacer));
    await pool.query(
      `INSERT INTO wa_auth_state (channel_id, key, value, updated_at)
       VALUES ($1, $2, $3, now())
       ON CONFLICT (channel_id, key)
       DO UPDATE SET value = EXCLUDED.value, updated_at = now()`,
      [channelId, key, encoded],
    );
  };

  const removeData = async (key: string): Promise<void> => {
    await pool.query(
      'DELETE FROM wa_auth_state WHERE channel_id = $1 AND key = $2',
      [channelId, key],
    );
  };

  const creds: AuthenticationCreds = (await readData('creds')) ?? initAuthCreds();

  return {
    state: {
      creds,
      keys: {
        get: async (type, ids) => {
          const data: { [id: string]: SignalDataTypeMap[typeof type] } = {};
          await Promise.all(
            ids.map(async (id) => {
              let value = await readData(`${type}-${id}`);
              // App-state sync keys must be handed back as protobuf objects,
              // not plain JSON, or history sync silently fails.
              if (type === 'app-state-sync-key' && value) {
                value = proto.Message.AppStateSyncKeyData.fromObject(value);
              }
              data[id] = value;
            }),
          );
          return data;
        },
        set: async (data) => {
          const tasks: Promise<void>[] = [];
          for (const category in data) {
            const entries = (data as any)[category];
            for (const id in entries) {
              const value = entries[id];
              const key = `${category}-${id}`;
              tasks.push(value ? writeData(key, value) : removeData(key));
            }
          }
          await Promise.all(tasks);
        },
      },
    },
    saveCreds: () => writeData('creds', creds),
    clear: async () => {
      await pool.query('DELETE FROM wa_auth_state WHERE channel_id = $1', [
        channelId,
      ]);
    },
  };
}
