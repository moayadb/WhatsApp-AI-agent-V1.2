import { env } from './env';

export interface SessionState {
  channel_id: string;
  status: string;
  link_method: string | null;
  pairing_code: string | null;
  qr: string | null;
  expires_at: string | null;
  last_error: string | null;
}

async function call<T>(
  path: string,
  init: { method: 'GET' | 'POST'; body?: unknown } = { method: 'GET' },
): Promise<T> {
  const response = await fetch(`${env.waServiceUrl}${path}`, {
    method: init.method,
    headers: {
      'content-type': 'application/json',
      'x-internal-token': env.internalToken,
    },
    body: init.body ? JSON.stringify(init.body) : undefined,
    // Linking talks to WhatsApp servers; a short timeout would abort a code
    // request that was about to succeed.
    signal: AbortSignal.timeout(30_000),
  });

  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`wa service ${response.status}: ${text}`);
  }
  return (await response.json()) as T;
}

export const wa = {
  start: (channelId: string, body: { method: string; phone?: string }) =>
    call<SessionState>(`/sessions/${channelId}/start`, { method: 'POST', body }),
  status: (channelId: string) => call<SessionState>(`/sessions/${channelId}`),
  stop: (channelId: string) =>
    call<{ ok: true }>(`/sessions/${channelId}/stop`, { method: 'POST' }),
  logout: (channelId: string) =>
    call<{ ok: true }>(`/sessions/${channelId}/logout`, { method: 'POST' }),
};
