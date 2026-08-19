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

/**
 * Alert copy, per language.
 *
 * These two detectors are the only alerts written without a model, so they are
 * also the only ones that used to arrive in English regardless of who was
 * reading them. `orgs.locale` is the manager's language and this is what the
 * push notification carries — the one place he reads an alert without the app
 * having a chance to re-render it.
 *
 * The app itself rebuilds these lines from `evidence` in whatever language it
 * is currently showing, so a locale changed after the fact does not leave a
 * stale sentence on screen. This text is the notification, and the fallback.
 */
interface SlaCopy {
  title: (agent: string, client: string) => string;
  insight: (waited: number, threshold: number) => string;
  action: string;
}

interface ColdCopy {
  title: (agent: string, client: string) => string;
  insight: (idleHours: number) => string;
  action: string;
}

const SLA_COPY: Record<string, SlaCopy> = {
  en: {
    title: (agent, client) => `${agent} has not replied to ${client}`,
    insight: (waited, threshold) =>
      `Waiting ${waited} min — threshold is ${threshold} min.`,
    action: 'Reassign or reply on behalf of the agent.',
  },
  ar: {
    title: (agent, client) => `${agent} لم يرد على ${client}`,
    insight: (waited, threshold) =>
      `في الانتظار منذ ${waited} دقيقة — الحد المسموح ${threshold} دقيقة.`,
    action: 'أعد إسناد المحادثة أو رُدّ نيابةً عن الموظف.',
  },
};

const COLD_COPY: Record<string, ColdCopy> = {
  en: {
    title: (agent, client) => `${client} has gone quiet with ${agent}`,
    insight: (idleHours) => `No messages for ${idleHours} h.`,
    action: 'Ask the agent for a follow-up plan.',
  },
  ar: {
    title: (agent, client) => `${client} توقّف عن الرد مع ${agent}`,
    insight: (idleHours) => `لا رسائل منذ ${idleHours} ساعة.`,
    action: 'اطلب من الموظف خطة متابعة.',
  },
};

/** A channel with no agent is the manager's own number, not a stray one. */
const OWN_NUMBER: Record<string, string> = { en: 'My number', ar: 'رقمي' };

const CLIENT_FALLBACK: Record<string, string> = { en: 'Client', ar: 'عميل' };

function copyFor<T>(table: Record<string, T>, locale: string | null): T {
  return table[locale ?? 'ar'] ?? table.ar;
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
    locale: string | null;
  }>(
    `SELECT cv.id AS conversation_id, cv.org_id, cv.channel_id, cv.agent_id,
            cv.contact_id, cv.awaiting_reply_since,
            EXTRACT(EPOCH FROM (now() - cv.awaiting_reply_since)) / 60 AS waited_minutes,
            CASE WHEN ct.is_vip
                 THEN COALESCE(s.vip_first_response_minutes, 5)
                 ELSE COALESCE(s.first_response_minutes, 15) END AS threshold,
            ag.name AS agent_name,
            ct.display_name AS contact_name, ct.phone_e164 AS contact_phone,
            ct.is_vip, o.locale
       FROM conversations cv
       JOIN contacts ct ON ct.id = cv.contact_id
       JOIN orgs o ON o.id = cv.org_id
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
    const copy = copyFor(SLA_COPY, row.locale);
    const who =
      row.contact_name ?? row.contact_phone ?? copyFor(CLIENT_FALLBACK, row.locale);
    const agent = row.agent_name ?? copyFor(OWN_NUMBER, row.locale);

    const alert = await createAlert({
      orgId: row.org_id,
      conversationId: row.conversation_id,
      channelId: row.channel_id,
      agentId: row.agent_id,
      contactId: row.contact_id,
      type: 'sla_breach',
      severity: slaSeverity(waited, Number(row.threshold)),
      // The app re-renders this from `evidence` in its own language; this text
      // is what the push notification carries, so it follows `orgs.locale`.
      title: copy.title(agent, who),
      insight: copy.insight(waited, Number(row.threshold)),
      recommendedAction: copy.action,
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
    locale: string | null;
  }>(
    `SELECT cv.id AS conversation_id, cv.org_id, cv.channel_id, cv.agent_id,
            cv.contact_id, cv.last_message_at,
            EXTRACT(EPOCH FROM (now() - cv.last_message_at)) / 3600 AS idle_hours,
            COALESCE(s.cold_lead_hours, 48) AS threshold,
            ag.name AS agent_name,
            ct.display_name AS contact_name, ct.phone_e164 AS contact_phone,
            o.locale
       FROM conversations cv
       JOIN contacts ct ON ct.id = cv.contact_id
       JOIN orgs o ON o.id = cv.org_id
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
    const copy = copyFor(COLD_COPY, row.locale);
    const who =
      row.contact_name ?? row.contact_phone ?? copyFor(CLIENT_FALLBACK, row.locale);
    const agent = row.agent_name ?? copyFor(OWN_NUMBER, row.locale);

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
      title: copy.title(agent, who),
      insight: copy.insight(idle),
      recommendedAction: copy.action,
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
