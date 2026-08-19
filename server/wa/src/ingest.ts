import type { WAMessage } from 'baileys';
import { pool } from './db';
import { env } from './env';
import { logger } from './logger';

/** A WhatsApp message reduced to the fields this product actually reasons about. */
export interface NormalizedMessage {
  waMessageId: string;
  remoteJid: string;
  direction: 'in' | 'out';
  body: string;
  mediaType: string | null;
  pushName: string | null;
  sentAt: Date;
  /**
   * Image/voice content, downloaded from WhatsApp and carried to the analysis
   * workflow: images go to the model as vision input, voice notes get
   * transcribed. Filled by the session layer (it owns the socket needed to
   * download), never persisted to the database — only the resulting
   * description/transcript is.
   */
  mediaBase64?: string | null;
  mediaMime?: string | null;
}

/**
 * Flatten Baileys' message union into text.
 *
 * Media captions count as text — an agent quoting a price under a floor-plan
 * image is exactly the kind of promise this product exists to catch.
 */
export function normalize(msg: WAMessage): NormalizedMessage | null {
  const remoteJid = msg.key?.remoteJid;
  if (!remoteJid) return null;

  // Status updates are noise. Groups are out of scope for the MVP: the product
  // measures one agent answering one client.
  if (remoteJid === 'status@broadcast' || remoteJid.endsWith('@g.us')) return null;

  const m = msg.message;
  if (!m) return null;

  let body = '';
  let mediaType: string | null = null;

  if (m.conversation) {
    body = m.conversation;
  } else if (m.extendedTextMessage?.text) {
    body = m.extendedTextMessage.text;
  } else if (m.imageMessage) {
    mediaType = 'image';
    body = m.imageMessage.caption ?? '';
  } else if (m.videoMessage) {
    mediaType = 'video';
    body = m.videoMessage.caption ?? '';
  } else if (m.audioMessage) {
    // Transcription happens in n8n; the row is written now so the response
    // clock starts on arrival, not on transcription.
    mediaType = m.audioMessage.ptt ? 'voice' : 'audio';
  } else if (m.documentMessage) {
    mediaType = 'document';
    body = m.documentMessage.caption ?? m.documentMessage.fileName ?? '';
  } else if (m.locationMessage) {
    mediaType = 'location';
  } else if (m.contactMessage || m.contactsArrayMessage) {
    mediaType = 'contact';
  } else {
    // Reactions, protocol messages, poll updates: not conversation content.
    return null;
  }

  const seconds = Number(msg.messageTimestamp ?? 0);
  return {
    waMessageId: msg.key.id ?? '',
    remoteJid,
    direction: msg.key.fromMe ? 'out' : 'in',
    body: body.trim(),
    mediaType,
    pushName: msg.pushName ?? null,
    sentAt: seconds > 0 ? new Date(seconds * 1000) : new Date(),
  };
}

function phoneFromJid(jid: string): string | null {
  const digits = jid.split('@')[0]?.split(':')[0];
  return digits && /^\d+$/.test(digits) ? `+${digits}` : null;
}

interface PersistResult {
  orgId: string;
  agentId: string | null;
  conversationId: string;
  contactId: string;
  messageId: string;
  isNewConversation: boolean;
}

/**
 * Write one message and move the conversation's clocks.
 *
 * `awaiting_reply_since` is the response-time product in a single column:
 * an inbound message starts it if nothing was already pending, and the agent's
 * next outbound message stops it. The sweeper in `api` only has to look for
 * rows where it is older than the org's threshold.
 */
export async function persist(
  channelId: string,
  msg: NormalizedMessage,
): Promise<PersistResult | null> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const channel = await client.query(
      'SELECT org_id, agent_id FROM channels WHERE id = $1',
      [channelId],
    );
    if (channel.rowCount === 0) {
      await client.query('ROLLBACK');
      return null;
    }
    const { org_id: orgId, agent_id: agentId } = channel.rows[0];

    const contact = await client.query(
      `INSERT INTO contacts (org_id, wa_jid, phone_e164, display_name)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (org_id, wa_jid) DO UPDATE
         SET display_name = COALESCE(contacts.display_name, EXCLUDED.display_name)
       RETURNING id`,
      [
        orgId,
        msg.remoteJid,
        phoneFromJid(msg.remoteJid),
        msg.direction === 'in' ? msg.pushName : null,
      ],
    );
    const contactId = contact.rows[0].id as string;

    const convo = await client.query(
      `INSERT INTO conversations (org_id, channel_id, contact_id, agent_id)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (channel_id, contact_id) DO UPDATE
         SET agent_id = COALESCE(conversations.agent_id, EXCLUDED.agent_id)
       RETURNING id, (xmax = 0) AS inserted`,
      [orgId, channelId, contactId, agentId],
    );
    const conversationId = convo.rows[0].id as string;
    const isNewConversation = convo.rows[0].inserted === true;

    const inserted = await client.query(
      `INSERT INTO messages
         (org_id, conversation_id, wa_message_id, direction, body, media_type, sent_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (conversation_id, wa_message_id) DO NOTHING
       RETURNING id`,
      [
        orgId,
        conversationId,
        msg.waMessageId,
        msg.direction,
        msg.body || null,
        msg.mediaType,
        msg.sentAt,
      ],
    );

    // Baileys re-delivers on reconnect. A duplicate must not restart the clock.
    if (inserted.rowCount === 0) {
      await client.query('ROLLBACK');
      return null;
    }

    if (msg.direction === 'in') {
      await client.query(
        `UPDATE conversations SET
           last_message_at = GREATEST(COALESCE(last_message_at, $2), $2),
           last_inbound_at = GREATEST(COALESCE(last_inbound_at, $2), $2),
           awaiting_reply_since = COALESCE(awaiting_reply_since, $2),
           cold_alerted_at = NULL,
           message_count = message_count + 1
         WHERE id = $1`,
        [conversationId, msg.sentAt],
      );
    } else {
      await client.query(
        `UPDATE conversations SET
           last_message_at = GREATEST(COALESCE(last_message_at, $2), $2),
           last_outbound_at = GREATEST(COALESCE(last_outbound_at, $2), $2),
           first_response_ms = COALESCE(
             first_response_ms,
             CASE WHEN awaiting_reply_since IS NOT NULL
                  THEN GREATEST(0, EXTRACT(EPOCH FROM ($2 - awaiting_reply_since)) * 1000)::bigint
             END),
           awaiting_reply_since = NULL,
           sla_alerted_at = NULL,
           cold_alerted_at = NULL,
           message_count = message_count + 1
         WHERE id = $1`,
        [conversationId, msg.sentAt],
      );
    }

    await client.query('COMMIT');
    return {
      orgId,
      agentId,
      conversationId,
      contactId,
      messageId: inserted.rows[0].id as string,
      isNewConversation,
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/** What the n8n analysis workflow answers with. */
interface Verdict {
  needs_attention?: boolean;
  type?: string;
  severity?: string;
  title?: string;
  insight?: string;
  recommended_action?: string;
  evidence?: unknown;
  /**
   * For voice notes: the transcription. For images: a one-line description.
   * Stored on the message row so the app can render media as readable text,
   * and so later thread context includes what was in the media.
   */
  transcript?: string;
}

/**
 * Hand the message plus recent thread context to n8n for AI scoring, then
 * deliver any verdict to the API's hook ourselves.
 *
 * Synchronous request/response with n8n, but called off the ingest hot path
 * (`void forwardToN8n(...)`) so WhatsApp delivery never waits on an LLM. The
 * verdict travels: n8n → here → API hook. All outbound calls, so the loop
 * works from a box with no public address — n8n never has to call back in.
 *
 * The ids for attribution stay HERE, not round-tripped through the model:
 * n8n only judges the conversation and returns the verdict; this service
 * attaches org/conversation/agent/message ids it already knows. A workflow
 * edit can therefore never mis-attribute an alert.
 */
export async function forwardToN8n(
  channelId: string,
  msg: NormalizedMessage,
  result: PersistResult,
): Promise<void> {
  if (!env.n8nAnalyzeUrl) return;

  try {
    // Both sides of the last 20 messages. Risk in a sales thread is often the
    // staff side — unauthorized promises, moving the client off-channel — so
    // the model has to see outbound messages too.
    const { rows: thread } = await pool.query(
      `SELECT direction, body, media_type, transcript, sent_at
         FROM messages
        WHERE conversation_id = $1
        ORDER BY sent_at DESC
        LIMIT 20`,
      [result.conversationId],
    );

    const { rows: meta } = await pool.query(
      `SELECT c.display_name, c.phone_e164, c.is_vip,
              a.name AS agent_name, ch.label AS channel_label,
              s.detect_unauthorized_promise, s.detect_off_channel,
              p.generated_prompt
         FROM contacts c
         LEFT JOIN conversations cv ON cv.id = $1
         LEFT JOIN agents a ON a.id = cv.agent_id
         LEFT JOIN channels ch ON ch.id = cv.channel_id
         LEFT JOIN org_settings s ON s.org_id = c.org_id
         LEFT JOIN org_profiles p ON p.org_id = c.org_id
        WHERE c.id = $2`,
      [result.conversationId, result.contactId],
    );

    const response = await fetch(env.n8nAnalyzeUrl, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-sanayed-secret': env.n8nSecret,
      },
      body: JSON.stringify({
        message: {
          direction: msg.direction,
          body: msg.body,
          media_type: msg.mediaType,
          media_base64: msg.mediaBase64 ?? null,
          media_mime: msg.mediaMime ?? null,
          sent_at: msg.sentAt.toISOString(),
        },
        contact: {
          display_name: meta[0]?.display_name ?? null,
          is_vip: meta[0]?.is_vip ?? false,
          agent_name: meta[0]?.agent_name ?? null,
        },
        // The monitoring instructions this org's own onboarding produced. n8n
        // puts them in front of the model, so two customers on the same
        // workflow get judged by their own rules rather than a generic list.
        org_prompt: meta[0]?.generated_prompt ?? null,
        detect_unauthorized_promise:
          meta[0]?.detect_unauthorized_promise !== false,
        detect_off_channel: meta[0]?.detect_off_channel !== false,
        // Oldest first reads naturally in a prompt.
        thread: thread.reverse(),
      }),
      // Generous: this waits on a model, not a database.
      signal: AbortSignal.timeout(45_000),
    });

    if (!response.ok) {
      logger.warn(
        { status: response.status, channelId },
        'n8n analyze webhook rejected the message',
      );
      return;
    }

    const verdict = (await response.json()) as Verdict;

    // Persist the transcript/description first: it is valuable whether or not
    // the message warranted an alert, and later analysis calls read it back as
    // thread context.
    if (verdict?.transcript && typeof verdict.transcript === 'string') {
      await pool.query(
        'UPDATE messages SET transcript = $2 WHERE id = $1',
        [result.messageId, verdict.transcript.slice(0, 20_000)],
      );
    }

    if (verdict?.needs_attention !== true) return;

    // Clamp the model's answers to the closed vocabularies before they reach
    // the API, so a creative model degrades to 'other'/'medium' instead of
    // failing validation and losing the alert entirely.
    const TYPES = new Set([
      'sla_breach', 'cold_lead', 'unauthorized_promise',
      'off_channel', 'escalation', 'other',
    ]);
    const SEVERITIES = new Set(['urgent', 'high', 'medium', 'low']);
    if (!TYPES.has(verdict.type ?? '')) verdict.type = 'other';
    if (!SEVERITIES.has(verdict.severity ?? '')) verdict.severity = 'medium';

    // Deliver to the API's existing hook — same validation, dedupe, WebSocket
    // broadcast and push gating as before; only the transport changed.
    const hook = await fetch(`${env.apiUrl}/api/hooks/n8n/alert`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-analyzer-secret': env.n8nSecret,
      },
      body: JSON.stringify({
        org_id: result.orgId,
        conversation_id: result.conversationId,
        channel_id: channelId,
        agent_id: result.agentId,
        contact_id: result.contactId,
        message_id: result.messageId,
        needs_attention: true,
        type: verdict.type ?? 'other',
        severity: verdict.severity ?? 'medium',
        title: verdict.title || 'AI flagged this conversation',
        insight: verdict.insight ?? undefined,
        recommended_action: verdict.recommended_action ?? undefined,
        evidence: verdict.evidence ?? undefined,
        event_at: msg.sentAt.toISOString(),
      }),
      signal: AbortSignal.timeout(10_000),
    });

    if (!hook.ok) {
      logger.warn(
        { status: hook.status, channelId },
        'API rejected the AI verdict',
      );
    } else {
      logger.info(
        { channelId, type: verdict.type, severity: verdict.severity },
        'AI verdict delivered',
      );
    }
  } catch (error) {
    logger.warn({ err: error, channelId }, 'n8n analysis failed');
  }
}
