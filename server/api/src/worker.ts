import { createAlert, type Severity } from './alerts';
import { many, pool } from './db';
import { env } from './env';
import { logger } from './logger';

/**
 * The two detectors that need no AI at all.
 *
 * Response time and silence are arithmetic on timestamps. Running them here
 * instead of through the LLM keeps the alert that matters most — the six-hour
 * hole that lost a AED 2M lead — free, instant, and immune to a model being
 * unavailable or a token budget running out.
 */

const BATCH = 200;

/** Later than late: past double the threshold this stops being a nudge. */
function slaSeverity(waitedMinutes: number, threshold: number): Severity {
  if (waitedMinutes >= threshold * 4) return 'urgent';
  if (waitedMinutes >= threshold * 2) return 'urgent';
  return 'high';
}

async function sweepUnanswered(): Promise<void> {
  const rows = await many<{
    conversation_id: string;
    org_id: string;
    channel_id: string;
    agent_id: string | null;
    contact_id: string;
    awaiting_reply_since: Date;
    waited_minutes: number;
    threshold: number;
    agent_name: string | null;
    contact_name: string | null;
    contact_phone: string | null;
    is_vip: boolean;
  }>(
    `SELECT cv.id AS conversation_id, cv.org_id, cv.channel_id, cv.agent_id,
            cv.contact_id, cv.awaiting_reply_since,
            EXTRACT(EPOCH FROM (now() - cv.awaiting_reply_since)) / 60 AS waited_minutes,
            CASE WHEN ct.is_vip
                 THEN COALESCE(s.vip_first_response_minutes, 5)
                 ELSE COALESCE(s.first_response_minutes, 15) END AS threshold,
            ag.name AS agent_name,
            ct.display_name AS contact_name, ct.phone_e164 AS contact_phone,
            ct.is_vip
       FROM conversations cv
       JOIN contacts ct ON ct.id = cv.contact_id
       LEFT JOIN agents ag ON ag.id = cv.agent_id
       LEFT JOIN org_settings s ON s.org_id = cv.org_id
      WHERE cv.awaiting_reply_since IS NOT NULL
        AND cv.sla_alerted_at IS NULL
        AND cv.awaiting_reply_since < now() - make_interval(
              mins => CASE WHEN ct.is_vip
                           THEN COALESCE(s.vip_first_response_minutes, 5)
                           ELSE COALESCE(s.first_response_minutes, 15) END)
      ORDER BY cv.awaiting_reply_since ASC
      LIMIT $1`,
    [BATCH],
  );

  for (const row of rows) {
    const waited = Math.round(Number(row.waited_minutes));
    const who = row.contact_name ?? row.contact_phone ?? 'Client';
    const agent = row.agent_name ?? 'Unassigned number';

    const alert = await createAlert({
      orgId: row.org_id,
      conversationId: row.conversation_id,
      channelId: row.channel_id,
      agentId: row.agent_id,
      contactId: row.contact_id,
      type: 'sla_breach',
      severity: slaSeverity(waited, Number(row.threshold)),
      // Client-side copy is localised from `type` + `evidence`; this English
      // line is the fallback that also lands in the push notification.
      title: `${agent} has not replied to ${who}`,
      insight: `Waiting ${waited} min — threshold is ${row.threshold} min.`,
      recommendedAction: 'Reassign or reply on behalf of the agent.',
      evidence: {
        waited_minutes: waited,
        threshold_minutes: Number(row.threshold),
        is_vip: row.is_vip,
      },
      eventAt: row.awaiting_reply_since,
      // One alert per unanswered turn, not one per sweep.
      dedupeKey: `sla:${row.conversation_id}:${row.awaiting_reply_since.toISOString()}`,
    });

    // Stamp regardless: a duplicate key means the alert already exists, and
    // either way this turn is now accounted for.
    await pool.query(
      'UPDATE conversations SET sla_alerted_at = now() WHERE id = $1',
      [row.conversation_id],
    );

    if (alert) {
      logger.info(
        { conversationId: row.conversation_id, waited },
        'sla breach alert raised',
      );
    }
  }
}

async function sweepColdLeads(): Promise<void> {
  const rows = await many<{
    conversation_id: string;
    org_id: string;
    channel_id: string;
    agent_id: string | null;
    contact_id: string;
    last_message_at: Date;
    idle_hours: number;
    threshold: number;
    agent_name: string | null;
    contact_name: string | null;
    contact_phone: string | null;
  }>(
    `SELECT cv.id AS conversation_id, cv.org_id, cv.channel_id, cv.agent_id,
            cv.contact_id, cv.last_message_at,
            EXTRACT(EPOCH FROM (now() - cv.last_message_at)) / 3600 AS idle_hours,
            COALESCE(s.cold_lead_hours, 48) AS threshold,
            ag.name AS agent_name,
            ct.display_name AS contact_name, ct.phone_e164 AS contact_phone
       FROM conversations cv
       JOIN contacts ct ON ct.id = cv.contact_id
       LEFT JOIN agents ag ON ag.id = cv.agent_id
       LEFT JOIN org_settings s ON s.org_id = cv.org_id
      WHERE cv.cold_alerted_at IS NULL
        AND cv.last_inbound_at IS NOT NULL
        AND cv.last_message_at < now() - make_interval(
              hours => COALESCE(s.cold_lead_hours, 48))
      ORDER BY cv.last_message_at ASC
      LIMIT $1`,
    [BATCH],
  );

  for (const row of rows) {
    const idle = Math.round(Number(row.idle_hours));
    const who = row.contact_name ?? row.contact_phone ?? 'Client';
    const agent = row.agent_name ?? 'Unassigned number';

    await createAlert({
      orgId: row.org_id,
      conversationId: row.conversation_id,
      channelId: row.channel_id,
      agentId: row.agent_id,
      contactId: row.contact_id,
      type: 'cold_lead',
      // Not urgent by design: a cold lead is a Monday problem, and treating it
      // as an emergency is how a notification feed becomes noise.
      severity: 'medium',
      title: `${who} has gone quiet with ${agent}`,
      insight: `No messages for ${idle} h.`,
      recommendedAction: 'Ask the agent for a follow-up plan.',
      evidence: { idle_hours: idle, threshold_hours: Number(row.threshold) },
      eventAt: row.last_message_at,
      dedupeKey: `cold:${row.conversation_id}:${row.last_message_at.toISOString()}`,
    });

    await pool.query(
      'UPDATE conversations SET cold_alerted_at = now() WHERE id = $1',
      [row.conversation_id],
    );
  }
}

async function sweep(): Promise<void> {
  try {
    await sweepUnanswered();
    await sweepColdLeads();
  } catch (error) {
    logger.error({ err: error }, 'detector sweep failed');
  }
}

export function startWorker(): NodeJS.Timeout {
  const interval = Math.max(15, env.workerIntervalSeconds) * 1000;
  logger.info({ intervalMs: interval }, 'response-time worker started');
  void sweep();
  return setInterval(() => void sweep(), interval);
}
