import { one } from './db';
import { logger } from './logger';
import { pushAlert } from './push';
import { broadcast } from './realtime';

export type AlertType =
  | 'sla_breach'
  | 'cold_lead'
  | 'unauthorized_promise'
  | 'off_channel'
  | 'escalation'
  | 'other';

export type Severity = 'urgent' | 'high' | 'medium' | 'low';

export interface AlertInput {
  orgId: string;
  conversationId?: string | null;
  channelId?: string | null;
  agentId?: string | null;
  contactId?: string | null;
  type: AlertType;
  severity: Severity;
  title: string;
  insight?: string | null;
  recommendedAction?: string | null;
  evidence?: unknown;
  eventAt: Date;
  /**
   * Idempotency key. The worker re-derives the same key every sweep, so a
   * still-unanswered lead produces one alert rather than one per minute.
   */
  dedupeKey?: string | null;
}

/** The alert shape the Flutter client consumes, joined with the human names. */
export const ALERT_SELECT = `
  SELECT a.id, a.type, a.severity, a.title, a.insight, a.recommended_action,
         a.evidence, a.event_at, a.status, a.completed_at, a.handling_ms,
         a.created_at, a.conversation_id, a.channel_id,
         a.agent_id, ag.name AS agent_name,
         a.contact_id, ct.display_name AS contact_name, ct.phone_e164 AS contact_phone,
         ct.is_vip
    FROM alerts a
    LEFT JOIN agents ag ON ag.id = a.agent_id
    LEFT JOIN contacts ct ON ct.id = a.contact_id
`;

/**
 * Write an alert, then tell everyone who needs to know.
 *
 * Returns `null` when the dedupe key already existed — the caller should treat
 * that as "nothing new happened", not as a failure.
 */
export async function createAlert(input: AlertInput): Promise<any | null> {
  const inserted = await one<{ id: string }>(
    `INSERT INTO alerts (org_id, conversation_id, channel_id, agent_id, contact_id,
                         type, severity, title, insight, recommended_action,
                         evidence, event_at, dedupe_key)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
     ON CONFLICT (org_id, dedupe_key) DO NOTHING
     RETURNING id`,
    [
      input.orgId,
      input.conversationId ?? null,
      input.channelId ?? null,
      input.agentId ?? null,
      input.contactId ?? null,
      input.type,
      input.severity,
      input.title,
      input.insight ?? null,
      input.recommendedAction ?? null,
      JSON.stringify(input.evidence ?? []),
      input.eventAt,
      input.dedupeKey ?? null,
    ],
  );

  if (!inserted) return null;

  const alert = await one(`${ALERT_SELECT} WHERE a.id = $1`, [inserted.id]);
  if (!alert) return null;

  broadcast(input.orgId, { type: 'alert.created', alert });

  void pushAlert({
    id: alert.id,
    org_id: input.orgId,
    severity: alert.severity,
    title: alert.title,
    insight: alert.insight,
    agent_name: alert.agent_name,
    contact_name: alert.contact_name,
  }).catch((error) => logger.warn({ err: error }, 'push failed'));

  return alert;
}
