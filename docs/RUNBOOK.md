# Runbook

## Two ways to run

| | Local development (this machine) | Production (Contabo) |
|---|---|---|
| Stack | native Windows processes | Docker Compose |
| Database | PostgreSQL 17 at `C:\Users\USER\pg17data`, port **5433** | `db` container, port 5432 |
| Web | `serve-web.js` on **8081** | Caddy on 80/443 |
| Why | a WireGuard tunnel blocks browser→WSL loopback | — |

The Docker stack in WSL still exists and is the production rehearsal. The native
Windows setup is a workaround for the VPN, not the deployment target.

---

## Start locally

```powershell
powershell -ExecutionPolicy Bypass -File "server\run-local.ps1"
```

Idempotent: starts Postgres if down, reuses existing secrets so sessions and
WhatsApp credentials survive. Then open **http://localhost:8081**.

Nothing auto-starts after a Windows reboot — Postgres runs user-space and the
services are plain processes.

Manual equivalent, if the script is not usable:

```bash
# 1. Postgres
"C:/Users/USER/pg17/pgsql/bin/pg_ctl.exe" -D "C:/Users/USER/pg17data" \
  -o "-p 5433 -c listen_addresses=127.0.0.1" -l "C:/Users/USER/pg17data/server.log" start

# 2. api   (from server/api)   PORT=3000
# 3. wa    (from server/wa)    PORT=3100
# 4. web   (from server)       WEB_PORT=8081
#    env for all: DATABASE_URL=postgres://postgres@127.0.0.1:5433/analyzer
#    plus JWT_SECRET / INTERNAL_TOKEN from server/.secrets.local
#    plus N8N_* from server/.env.local
```

### Health checks

```bash
curl http://127.0.0.1:3000/api/health          # {"ok":true}
curl http://localhost:8081/api/health          # same, through the app's origin
```

WhatsApp session state:

```sql
SELECT phone_e164, status, last_connected_at, last_error FROM channels;
```

`connected` is the good state. `logged_out` means the agent revoked the device
and it needs re-linking. The `wa` log line `whatsapp session connected` confirms
a successful resume.

---

## Inspect the database

Double-click `server\db-shell.cmd`, or:

```bash
"C:/Users/USER/pg17/pgsql/bin/psql.exe" -h 127.0.0.1 -p 5433 -U postgres -d analyzer
```

Useful queries:

```sql
-- recent traffic
SELECT direction, media_type, left(body,50), left(transcript,40), sent_at
FROM messages ORDER BY sent_at DESC LIMIT 20;

-- alerts with who and what
SELECT a.type, a.severity, a.status, a.title, c.display_name, a.event_at
FROM alerts a LEFT JOIN contacts c ON c.id = a.contact_id
ORDER BY a.event_at DESC;

-- this org's monitoring prompt (the AI's instructions)
SELECT prompt_source, generated_prompt FROM org_profiles WHERE generated_prompt IS NOT NULL;

-- who is waiting for a reply right now
SELECT c.display_name, round(extract(epoch FROM (now()-cv.awaiting_reply_since))/60) AS waiting_min
FROM conversations cv JOIN contacts c ON c.id = cv.contact_id
WHERE cv.awaiting_reply_since IS NOT NULL;
```

`\dt` lists tables, `\d alerts` describes one, `\q` exits.
Avoid `DELETE`/`UPDATE` on `wa_auth_state` and `channels` unless you intend to
unlink a number.

---

## Backup

The database holds the WhatsApp session credentials, so losing it means every
agent re-links.

```bash
# local
"C:/Users/USER/pg17/pgsql/bin/pg_dump.exe" -h 127.0.0.1 -p 5433 -U postgres analyzer -f backup.sql

# production
docker compose exec -T db pg_dump -U analyzer analyzer | gzip > backup-$(date +%F).sql.gz
```

**Never run `docker compose down -v`** on the server: `-v` destroys the volume.

---

## Deploy to Contabo

```bash
cd server && ./deploy.sh app.example.com
```

Generates `.env` with fresh secrets on first run, preserves them after, builds
and starts the stack, waits for health. The Flutter web bundle is **not** built
on the server:

```bash
flutter build web --release          # on a dev machine
scp -r build/web/* USER@HOST:/path/server/web/
```

DNS must already point at the box or Let's Encrypt cannot issue.

---

## Wiring n8n

Both workflows live in `n8n/` and are already deployed to
`https://n8n-training.sanayadtech.com`.

Re-importing from the repo requires two substitutions:

1. Replace `__N8N_WEBHOOK_SECRET__` in the Code nodes with the real value from
   `server/.env.local` (`N8N_WEBHOOK_SECRET`).
2. Attach the OpenAI credential to the model nodes.

Then set in the app's environment:

```
N8N_INTAKE_URL=https://…/webhook/sanayed-intake
N8N_ANALYZE_URL=https://…/webhook/sanayed-analyze
N8N_WEBHOOK_SECRET=<same value>
```

Both webhooks are synchronous request/response and called **outbound** from the
app, which is why the whole loop works from a machine with no public address.

Verify without touching WhatsApp:

```bash
curl -s -X POST https://…/webhook/sanayed-analyze \
  -H 'content-type: application/json; charset=utf-8' \
  -H 'x-sanayed-secret: <secret>' \
  --data-binary @payload.json
```

A rejected secret returns an **empty 200**, not a 401.

---

## Common symptoms

| Symptom | Likely cause |
|---|---|
| Pairing code never appears | old build without the 515 fix; or container MTU ≠ host MTU |
| App loads, API calls fail from the browser only | WireGuard blocking loopback → use the LAN address |
| Messages stop arriving, `channels.status` still `connected` | `wa` lost its DB connection at boot — check for `resume failed` in its log |
| Alert has no agent name | the number is linked to the manager, not an agent |
| Interview replies in the wrong language | it mirrors the manager's own language; the app locale is only a fallback |
| Everything down after reboot | nothing auto-starts; run `run-local.ps1` |

---

## Push notifications

In-app alerts (WebSocket) work with no setup. Push to the phone additionally
needs one credential: see `server/secrets/README.md`. Until the file exists,
push is silently disabled and everything else works.

The sender lives in `server/api/src/push.ts` and already gates on the org's
`min_push_severity` and quiet hours; urgent alerts bypass quiet hours.
