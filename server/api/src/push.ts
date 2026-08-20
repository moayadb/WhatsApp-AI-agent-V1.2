import { createSign } from 'node:crypto';
import { readFile } from 'node:fs/promises';

import { many, one } from './db';
import { env } from './env';
import { logger } from './logger';

/**
 * FCM HTTP v1 sender, written against the REST API directly.
 *
 * Firebase Messaging is the one Google product this stack still touches, and it
 * has no paid tier — but its SDK drags in a large dependency tree, so the
 * service-account JWT is minted here with node:crypto instead.
 */

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

let account: ServiceAccount | null = null;
let cachedToken: { value: string; expiresAt: number } | null = null;

function base64url(value: object | Buffer): string {
  const buffer = Buffer.isBuffer(value)
    ? value
    : Buffer.from(JSON.stringify(value));
  return buffer.toString('base64url');
}

/**
 * Whether a service account is configured at all.
 *
 * Push is optional infrastructure: the product works without it, the manager
 * just has to open the app himself. But "no notifications arrived" and "no
 * notifications were sent" look identical from the outside, so the boot log
 * says which one this deployment is.
 */
export function pushConfigured(): boolean {
  return env.fcmServiceAccountFile.length > 0;
}

let disabledLogged = false;

async function loadAccount(): Promise<ServiceAccount | null> {
  if (account) return account;
  if (!env.fcmServiceAccountFile) {
    if (!disabledLogged) {
      disabledLogged = true;
      logger.info(
        'push disabled: FCM_SERVICE_ACCOUNT_FILE is not set; alerts will not be pushed',
      );
    }
    return null;
  }
  try {
    account = JSON.parse(
      await readFile(env.fcmServiceAccountFile, 'utf8'),
    ) as ServiceAccount;
    return account;
  } catch (error) {
    logger.warn({ err: error }, 'FCM service account unreadable; push disabled');
    return null;
  }
}

async function accessToken(): Promise<string | null> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) {
    return cachedToken.value;
  }

  const serviceAccount = await loadAccount();
  if (!serviceAccount) return null;

  const now = Math.floor(Date.now() / 1000);
  const unsigned = [
    base64url({ alg: 'RS256', typ: 'JWT' }),
    base64url({
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  ].join('.');

  const signer = createSign('RSA-SHA256');
  signer.update(unsigned);
  signer.end();
  const assertion = `${unsigned}.${base64url(signer.sign(serviceAccount.private_key))}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!response.ok) {
    logger.warn({ status: response.status }, 'FCM token exchange failed');
    return null;
  }

  const json = (await response.json()) as {
    access_token: string;
    expires_in: number;
  };
  cachedToken = {
    value: json.access_token,
    expiresAt: Date.now() + json.expires_in * 1000,
  };
  return cachedToken.value;
}

const SEVERITY_RANK: Record<string, number> = {
  urgent: 4,
  high: 3,
  medium: 2,
  low: 1,
};

/** Local hour in the org's timezone, for the quiet-hours check. */
function localHour(timezone: string): number {
  try {
    return Number(
      new Intl.DateTimeFormat('en-GB', {
        hour: 'numeric',
        hour12: false,
        timeZone: timezone,
      }).format(new Date()),
    );
  } catch {
    return new Date().getUTCHours();
  }
}

function inQuietHours(
  hour: number,
  start: number | null,
  end: number | null,
): boolean {
  if (start === null || end === null) return false;
  // Windows that wrap midnight (22 → 07) are the normal case, not the edge one.
  return start <= end ? hour >= start && hour < end : hour >= start || hour < end;
}

export interface PushableAlert {
  id: string;
  org_id: string;
  severity: string;
  title: string;
  insight: string | null;
  agent_name?: string | null;
  contact_name?: string | null;
}

/**
 * Notify a manager only when their intervention is actually required.
 *
 * Two gates before anything leaves the box: the alert must meet the org's
 * minimum severity, and it must not be the middle of the night. Urgent alerts
 * ignore quiet hours — a AED 2M lead going unanswered at 23:00 is exactly the
 * case the product exists for.
 */
export async function pushAlert(alert: PushableAlert): Promise<void> {
  const settings = await one<{
    min_push_severity: string;
    quiet_hours_start: number | null;
    quiet_hours_end: number | null;
    timezone: string;
  }>(
    `SELECT s.min_push_severity, s.quiet_hours_start, s.quiet_hours_end, o.timezone
       FROM orgs o
       LEFT JOIN org_settings s ON s.org_id = o.id
      WHERE o.id = $1`,
    [alert.org_id],
  );
  if (!settings) return;

  const minRank = SEVERITY_RANK[settings.min_push_severity ?? 'high'] ?? 3;
  if ((SEVERITY_RANK[alert.severity] ?? 0) < minRank) return;

  if (
    alert.severity !== 'urgent' &&
    inQuietHours(
      localHour(settings.timezone),
      settings.quiet_hours_start,
      settings.quiet_hours_end,
    )
  ) {
    logger.debug({ alertId: alert.id }, 'suppressed by quiet hours');
    return;
  }

  const token = await accessToken();
  if (!token) return;

  const projectId = env.fcmProjectId || account?.project_id;
  if (!projectId) return;

  const devices = await many<{ id: string; token: string }>(
    `SELECT d.id, d.token
       FROM devices d
       JOIN users u ON u.id = d.user_id
      WHERE u.org_id = $1`,
    [alert.org_id],
  );

  const subtitle = [alert.agent_name, alert.contact_name]
    .filter(Boolean)
    .join(' · ');

  for (const device of devices) {
    try {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            authorization: `Bearer ${token}`,
            'content-type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: device.token,
              notification: {
                title: alert.title,
                body: alert.insight ?? subtitle,
              },
              data: {
                alert_id: alert.id,
                severity: alert.severity,
                subtitle,
              },
              android: { priority: 'HIGH' },
              apns: {
                headers: { 'apns-priority': '10' },
                payload: { aps: { sound: 'default' } },
              },
            },
          }),
        },
      );

      // 404/403 mean the install is gone. Keeping dead tokens slows every
      // later send, so drop them on sight.
      if (response.status === 404 || response.status === 403) {
        await many('DELETE FROM devices WHERE id = $1', [device.id]);
      } else if (!response.ok) {
        logger.warn({ status: response.status }, 'FCM send failed');
      }
    } catch (error) {
      logger.warn({ err: error }, 'FCM send threw');
    }
  }
}
