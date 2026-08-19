import type { WebSocket } from 'ws';
import { logger } from './logger';

/**
 * Live fan-out to every open app session of one org.
 *
 * This is what replaces the Firestore snapshot listener the Flutter app used
 * to hold: the client subscribes once and the server pushes alerts, channel
 * status changes, and agent-board refreshes as they happen.
 */
const clientsByOrg = new Map<string, Set<WebSocket>>();

export function addClient(orgId: string, socket: WebSocket): void {
  const set = clientsByOrg.get(orgId) ?? new Set<WebSocket>();
  set.add(socket);
  clientsByOrg.set(orgId, set);
}

export function removeClient(orgId: string, socket: WebSocket): void {
  const set = clientsByOrg.get(orgId);
  if (!set) return;
  set.delete(socket);
  if (set.size === 0) clientsByOrg.delete(orgId);
}

export type RealtimeEvent =
  | { type: 'alert.created'; alert: unknown }
  | { type: 'alert.updated'; alert: unknown }
  | { type: 'channel.status'; channel: unknown };

export function broadcast(orgId: string, event: RealtimeEvent): void {
  const set = clientsByOrg.get(orgId);
  if (!set || set.size === 0) return;

  const payload = JSON.stringify(event);
  for (const socket of set) {
    try {
      // 1 === OPEN. Anything else is mid-close; the close handler cleans up.
      if (socket.readyState === 1) socket.send(payload);
    } catch (error) {
      logger.warn({ err: error, orgId }, 'failed to push realtime event');
    }
  }
}
