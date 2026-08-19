# Server — Multi-Channel AI Analyzer

Self-hosted stack. Nothing here bills by the month except the OpenAI tokens the
n8n workflow spends, and even those only for the two detectors that need a model.

```
                    Caddy (TLS, :443)
                          │
        ┌─────────────────┼──────────────────┐
        │                 │                  │
   Flutter web         api :3000          (nothing else is public)
                          │
              ┌───────────┴───────────┐
              │                       │
        Postgres :5432           wa :3100  ── Baileys ⇄ WhatsApp
                                     │
                                     └── POST ──► n8n cloud ──► POST /api/hooks/n8n/alert
```

| Service | What it is | Public? |
|---|---|---|
| `caddy` | TLS, reverse proxy, serves the Flutter web build | yes, 80/443 |
| `api` | REST + WebSocket for the app, and the response-time worker | via Caddy |
| `wa` | Baileys sessions — one live WhatsApp connection per linked number | **no** |
| `db` | Postgres 17, single source of truth | **no** |

`wa` is never exposed. It holds live WhatsApp credentials for every agent's
number; only `api` reaches it, over the compose network, with a shared token.

## Deploy on Contabo

```bash
git clone <this repo> && cd server
cp .env.example .env
```

Fill in `.env` — the three secrets first:

```bash
openssl rand -hex 32   # JWT_SECRET
openssl rand -hex 32   # INTERNAL_TOKEN
openssl rand -hex 32   # N8N_WEBHOOK_SECRET
```

Set `APP_DOMAIN` to the domain pointed at the box, and `POSTGRES_PASSWORD` /
`DATABASE_URL` to the same password. Then:

```bash
docker compose up -d --build
```

The API applies `db/migrations/*.sql` on boot, in order, each in its own
transaction — no separate migration step.

Check it:

```bash
curl https://YOUR-DOMAIN/api/health
```

### Flutter web

```bash
flutter build web --dart-define=API_BASE_URL=https://YOUR-DOMAIN
```

Copy `build/web` to `server/web/` on the box. Caddy serves it at the root and
falls back to `index.html`, so deep links work.

## Wiring n8n

1. Import `../n8n/analyze-message.json`.
2. Attach your OpenAI credential to **OpenAI Chat Model**.
3. Set the **Raise alert** node's URL to `https://YOUR-DOMAIN/api/hooks/n8n/alert`
   and add `ANALYZER_SECRET` to the n8n environment, matching
   `N8N_WEBHOOK_SECRET`.
4. Activate, copy the production webhook URL into `N8N_ANALYZE_URL` in `.env`,
   and `docker compose up -d` again.

Until that is done the app still works: the response-time and cold-lead
detectors are pure arithmetic in the worker and never touch a model.

## Which detector runs where

| Alert | Where | Cost |
|---|---|---|
| `sla_breach` — nobody replied in time | `api` worker, SQL | free |
| `cold_lead` — thread went silent | `api` worker, SQL | free |
| `unauthorized_promise` — agent guaranteed something | n8n + OpenAI | tokens |
| `off_channel` — agent moved the client off-channel | n8n + OpenAI | tokens |
| `escalation` — client angry or threatening | n8n + OpenAI | tokens |

The six-hour hole that lost a AED 2M lead is the first row: no model involved,
so it fires even if OpenAI is down or the budget is spent.

## Linking a WhatsApp number

`POST /api/channels` with `method: "pairing_code"` and the number in E.164
returns an eight-character code. The agent opens **WhatsApp → Linked devices →
Link with phone number instead** and types it. The app polls
`GET /api/channels/:id/link` until `status` becomes `connected`.

`method: "qr"` returns a `data:` URL instead, for when the phone is in reach.

Codes expire in about a minute — `POST /api/channels/:id/relink` issues a fresh one.

Notes that matter in production:

- **Sessions survive restarts.** Baileys credentials live in Postgres
  (`wa_auth_state`), not on the container filesystem, so `docker compose
  restart` does not cost ten agents a re-link. `resumeAll()` brings them back,
  staggered.
- **The agent's phone keeps its notifications.** The socket connects with
  `markOnlineOnConnect: false`; without it, WhatsApp routes notifications to the
  linked device and the agent stops hearing their own messages.
- **Unlinking is visible.** If an agent revokes the device, the channel goes to
  `logged_out` and shows on the dashboard as needing attention. A monitoring
  product that silently stops monitoring is worse than none.
- **This uses the WhatsApp Web protocol, not the official Business API.**
  That is the only way "link with phone number" exists at all, and it carries
  ban risk for the linked number. Worth knowing before ten agents are on it.

## Local development without Docker

```bash
cd api && npm install && npm run build
DATABASE_URL=postgres://… JWT_SECRET=dev INTERNAL_TOKEN=dev \
MIGRATIONS_DIR=../db/migrations node dist/index.js
```

`wa` additionally needs `git` and a C toolchain, because Baileys builds
`libsignal` from source.
