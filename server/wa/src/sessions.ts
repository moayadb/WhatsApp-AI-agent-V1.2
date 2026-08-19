import makeWASocket, {
  Browsers,
  DisconnectReason,
  downloadMediaMessage,
  fetchLatestBaileysVersion,
  makeCacheableSignalKeyStore,
} from 'baileys';
import type { WAMessage, WASocket } from 'baileys';
import QRCode from 'qrcode';

import { usePostgresAuthState } from './auth-state';
import { pool, updateChannel, type ChannelStatus } from './db';
import {
  forwardToN8n,
  normalize,
  persist,
  type NormalizedMessage,
} from './ingest';
import { baileysLogger, logger } from './logger';

export type LinkMethod = 'pairing_code' | 'qr';

interface Session {
  channelId: string;
  sock: WASocket;
  status: ChannelStatus;
  method: LinkMethod;
  /** Digits only, no `+`. Required for pairing-code linking. */
  phone?: string;
  pairingCode?: string;
  /** QR as a data: URL, ready for an <img> in Flutter. */
  qr?: string;
  expiresAt?: Date;
  lastError?: string;
  /** requestPairingCode may be called exactly once per socket. */
  pairingRequested: boolean;
  /** True while an operator-initiated stop is in flight — suppresses reconnect. */
  stopping: boolean;
  attempts: number;
  saveCreds: () => Promise<void>;
  clearCreds: () => Promise<void>;
}

const sessions = new Map<string, Session>();

/**
 * Reconnect attempts, kept outside the session because each reconnect builds a
 * brand-new session object. Storing it there would reset the backoff every time
 * and turn a flapping connection into a hammering one.
 */
const attemptsByChannel = new Map<string, number>();

/** Exponential backoff, capped. WhatsApp punishes reconnect storms. */
function backoffMs(attempts: number): number {
  return Math.min(60_000, 2_000 * 2 ** Math.min(attempts, 5));
}

export function snapshot(channelId: string) {
  const session = sessions.get(channelId);
  if (!session) return null;
  return {
    channel_id: channelId,
    status: session.status,
    link_method: session.method,
    pairing_code: session.pairingCode ?? null,
    qr: session.qr ?? null,
    expires_at: session.expiresAt?.toISOString() ?? null,
    last_error: session.lastError ?? null,
  };
}

export function isRunning(channelId: string): boolean {
  return sessions.has(channelId);
}

async function setStatus(
  session: Session,
  status: ChannelStatus,
  patch: Record<string, unknown> = {},
): Promise<void> {
  session.status = status;
  await updateChannel(session.channelId, { status, ...patch });
}

/**
 * Open (or reopen) a WhatsApp session for one channel.
 *
 * `method: 'pairing_code'` is the "Link new device with phone number" flow —
 * WhatsApp emits an 8-character code the agent types into
 * WhatsApp → Linked devices → Link with phone number instead. It is only
 * available on an unregistered socket, and only after the connection reaches
 * the point where it would otherwise show a QR, which is why the request is
 * made from inside the `qr` event rather than immediately after construction.
 */
export async function startSession(
  channelId: string,
  options: { method: LinkMethod; phone?: string },
): Promise<ReturnType<typeof snapshot>> {
  const existing = sessions.get(channelId);
  if (existing) {
    // Already linking or live — hand back the current code instead of racing a
    // second socket onto the same credentials.
    return snapshot(channelId);
  }

  const phone = options.phone?.replace(/[^\d]/g, '');
  if (options.method === 'pairing_code' && !phone) {
    throw new Error('phone is required for pairing-code linking');
  }

  const { state, saveCreds, clear } = await usePostgresAuthState(pool, channelId);
  const { version } = await fetchLatestBaileysVersion();

  const sock = makeWASocket({
    version,
    auth: {
      creds: state.creds,
      // Signal key lookups are hot; without the cache every decrypt is a
      // round trip to Postgres.
      keys: makeCacheableSignalKeyStore(state.keys, baileysLogger),
    },
    logger: baileysLogger,
    printQRInTerminal: false,
    browser: Browsers.ubuntu('Chrome'),
    // Critical for this product: the agent's own phone must keep ringing.
    // Marking the linked device online silently steals their notifications.
    markOnlineOnConnect: false,
    syncFullHistory: false,
    generateHighQualityLinkPreview: false,
  });

  const session: Session = {
    channelId,
    sock,
    status: state.creds.registered ? 'disconnected' : 'pairing',
    method: options.method,
    phone,
    pairingRequested: false,
    stopping: false,
    attempts: attemptsByChannel.get(channelId) ?? 0,
    saveCreds,
    clearCreds: clear,
  };
  sessions.set(channelId, session);

  await updateChannel(channelId, {
    status: session.status,
    link_method: options.method,
    ...(phone ? { phone_e164: `+${phone}` } : {}),
  });

  sock.ev.on('creds.update', () => {
    saveCreds().catch((err) =>
      logger.error({ err, channelId }, 'failed to persist credentials'),
    );
  });

  sock.ev.on('connection.update', async (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      try {
        if (session.method === 'pairing_code' && !session.pairingRequested) {
          session.pairingRequested = true;
          const code = await sock.requestPairingCode(session.phone!);
          // WhatsApp shows it as XXXX-XXXX; matching that removes a whole
          // class of "it says my code is wrong" support messages.
          session.pairingCode = code.match(/.{1,4}/g)?.join('-') ?? code;
          session.expiresAt = new Date(Date.now() + 60_000);
          await setStatus(session, 'pairing', {
            pairing_code: session.pairingCode,
            pairing_expires_at: session.expiresAt,
            qr: null,
          });
          logger.info({ channelId }, 'pairing code issued');
        } else if (session.method === 'qr') {
          session.qr = await QRCode.toDataURL(qr, { margin: 1, width: 320 });
          session.expiresAt = new Date(Date.now() + 60_000);
          await setStatus(session, 'pairing', {
            qr: session.qr,
            pairing_expires_at: session.expiresAt,
            pairing_code: null,
          });
        }
      } catch (err) {
        session.lastError = (err as Error).message;
        logger.error({ err, channelId }, 'failed to issue link challenge');
        await setStatus(session, 'error', { last_error: session.lastError });
      }
      return;
    }

    if (connection === 'open') {
      session.attempts = 0;
      attemptsByChannel.delete(channelId);
      session.pairingCode = undefined;
      session.qr = undefined;
      session.lastError = undefined;
      const jid = sock.user?.id ?? null;
      await setStatus(session, 'connected', {
        wa_jid: jid,
        pairing_code: null,
        qr: null,
        pairing_expires_at: null,
        last_error: null,
        last_connected_at: new Date(),
      });
      logger.info({ channelId, jid }, 'whatsapp session connected');
      return;
    }

    if (connection === 'close') {
      const statusCode = (lastDisconnect?.error as any)?.output?.statusCode;
      sessions.delete(channelId);

      if (session.stopping) {
        await setStatus(session, 'disconnected', {
          last_disconnected_at: new Date(),
        });
        return;
      }

      // Logged out means the agent revoked the device (or WhatsApp did). The
      // credentials are dead — keeping them would loop forever on 401.
      if (statusCode === DisconnectReason.loggedOut) {
        await clear();
        await setStatus(session, 'logged_out', {
          last_disconnected_at: new Date(),
          wa_jid: null,
          last_error: 'device unlinked from WhatsApp',
        });
        logger.warn({ channelId }, 'session logged out — re-link required');
        return;
      }

      // 515 = restart required, and it is the NORMAL last step of linking:
      // the moment the user types the pairing code, WhatsApp tears the stream
      // down and expects the client to reconnect, and only then does the
      // account finish registering.
      //
      // This has to be handled BEFORE the "never registered" check below,
      // because at this instant the credentials are legitimately not yet
      // marked registered. Getting the order wrong makes a successful pairing
      // look like an abandoned one — the session is dropped as "linking was
      // not completed" and the app spins on the code screen forever.
      if (statusCode === DisconnectReason.restartRequired) {
        logger.info({ channelId }, 'restart required after pairing — reconnecting');
        await setStatus(session, 'syncing', {
          pairing_code: null,
          qr: null,
          pairing_expires_at: null,
          last_error: null,
        });
        setTimeout(() => {
          startSession(channelId, {
            method: session.method,
            phone: session.phone,
          }).catch((err) =>
            logger.error({ err, channelId }, 'restart reconnect failed'),
          );
        }, 500);
        return;
      }

      // A socket that never registered and then closed means the code expired
      // or was never entered. Do not silently retry: the user has to ask again.
      if (!session.sock.authState.creds.registered) {
        await setStatus(session, 'disconnected', {
          pairing_code: null,
          qr: null,
          pairing_expires_at: null,
          last_disconnected_at: new Date(),
          last_error: 'linking was not completed',
        });
        return;
      }

      const delay = backoffMs(session.attempts);
      attemptsByChannel.set(channelId, session.attempts + 1);
      await setStatus(session, 'disconnected', {
        last_disconnected_at: new Date(),
        last_error: statusCode ? `disconnect ${statusCode}` : null,
      });
      logger.info({ channelId, statusCode, delay }, 'reconnecting');
      setTimeout(() => {
        startSession(channelId, {
          method: session.method,
          phone: session.phone,
        }).catch((err) =>
          logger.error({ err, channelId }, 'reconnect failed'),
        );
      }, delay);
    }
  });

  sock.ev.on('messages.upsert', async ({ messages, type }) => {
    // `append` is history backfill; only `notify` is live traffic. Scoring the
    // backlog on first link would alert on months of old conversations.
    if (type !== 'notify') return;

    for (const raw of messages) {
      try {
        const message = normalize(raw);
        if (!message) continue;
        const result = await persist(channelId, message);
        if (!result) continue;
        // Media is fetched AFTER persisting: the response clock starts on
        // arrival, and a failed download must not lose the message row.
        await attachMedia(sock, raw, message);
        void forwardToN8n(channelId, message, result);
      } catch (err) {
        logger.error({ err, channelId }, 'failed to ingest message');
      }
    }
  });

  return snapshot(channelId);
}

/**
 * Download image/voice content so the analysis can actually see it.
 *
 * Bounded at 8 MB: this exists for floor plans, payment screenshots and voice
 * notes, not videos. Failure is non-fatal — the message still gets analysed as
 * "[image]" / "[voice]" the way it did before media support existed.
 */
const MEDIA_CAP_BYTES = 8 * 1024 * 1024;

async function attachMedia(
  sock: WASocket,
  raw: WAMessage,
  message: NormalizedMessage,
): Promise<void> {
  if (!message.mediaType) return;
  if (!['image', 'voice', 'audio'].includes(message.mediaType)) return;

  const media = raw.message?.imageMessage ?? raw.message?.audioMessage;
  const declared = Number(media?.fileLength ?? 0);
  if (declared > MEDIA_CAP_BYTES) {
    logger.info(
      { size: declared, type: message.mediaType },
      'media skipped — larger than the analysis cap',
    );
    return;
  }

  try {
    const buffer = (await downloadMediaMessage(
      raw,
      'buffer',
      {},
      // reuploadRequest lets WhatsApp re-serve expired media through our own
      // session instead of failing on older messages.
      { logger: baileysLogger, reuploadRequest: sock.updateMediaMessage },
    )) as Buffer;

    if (buffer.length === 0 || buffer.length > MEDIA_CAP_BYTES) return;
    message.mediaBase64 = buffer.toString('base64');
    message.mediaMime = media?.mimetype ?? null;
  } catch (err) {
    logger.warn({ err, type: message.mediaType }, 'media download failed');
  }
}

/** Close the socket but keep credentials, so it can resume later. */
export async function stopSession(channelId: string): Promise<void> {
  const session = sessions.get(channelId);
  if (!session) return;
  session.stopping = true;
  try {
    session.sock.end(undefined);
  } catch {
    /* already closed */
  }
  sessions.delete(channelId);
  await updateChannel(channelId, {
    status: 'disconnected',
    last_disconnected_at: new Date(),
  });
}

/** Unlink for good: tell WhatsApp, then destroy the credentials. */
export async function logoutSession(channelId: string): Promise<void> {
  const session = sessions.get(channelId);
  if (session) {
    session.stopping = true;
    try {
      await session.sock.logout();
    } catch (err) {
      logger.warn({ err, channelId }, 'logout call failed; clearing anyway');
    }
    sessions.delete(channelId);
    await session.clearCreds();
  } else {
    await pool.query('DELETE FROM wa_auth_state WHERE channel_id = $1', [
      channelId,
    ]);
  }
  await updateChannel(channelId, {
    status: 'logged_out',
    wa_jid: null,
    pairing_code: null,
    qr: null,
    pairing_expires_at: null,
    last_disconnected_at: new Date(),
  });
}

/**
 * Bring previously linked channels back up after a restart.
 *
 * Only channels that already hold credentials are resumed — a channel still
 * mid-linking has nothing to resume, and re-opening it would burn the code the
 * user is currently looking at.
 */
export async function resumeAll(): Promise<void> {
  const { rows } = await pool.query(
    `SELECT c.id, c.phone_e164, c.link_method
       FROM channels c
       JOIN wa_auth_state s ON s.channel_id = c.id AND s.key = 'creds'
      WHERE c.status <> 'logged_out'`,
  );
  logger.info({ count: rows.length }, 'resuming whatsapp sessions');

  for (const row of rows) {
    try {
      await startSession(row.id, {
        method: (row.link_method as LinkMethod) ?? 'pairing_code',
        phone: row.phone_e164 ?? undefined,
      });
    } catch (err) {
      logger.error({ err, channelId: row.id }, 'failed to resume session');
    }
    // Stagger: ten sockets handshaking at once looks like an attack.
    await new Promise((resolve) => setTimeout(resolve, 1_500));
  }
}
