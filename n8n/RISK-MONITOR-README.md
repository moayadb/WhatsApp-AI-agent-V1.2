# wacrm Risk Monitor — n8n workflow

`wacrm-risk-monitor.json` watches WhatsApp conversations flowing through
wacrm and writes an alert to Firestore when the exchange between a customer
and sales staff turns risky. The Flutter app (Tulip Alerts) displays them live.

```
WhatsApp ⇄ Meta Cloud API ⇄ wacrm (inbox, localhost:3000, tunneled)
                                │  outbound webhook: message.received
                                ▼
      n8n Cloud: Webhook → Filter → Fetch Contact → Fetch Thread (20 msgs)
                                │
                 Build Transcript (chronological, Customer:/Staff:)
                                │
                 AI risk assessment (two-sided: catches staff misconduct too)
                                │
              risky? ──yes──► Firestore `alerts` ──► Flutter app
                     └─no──► stop
```

## Why this shape

- **wacrm's outbound webhooks** (`message.received`) are used instead of an
  automation `send_webhook` step: the automation template can only interpolate
  `{{message.text}}`, while the outbound event carries `conversation_id` +
  `contact_id`, letting n8n fetch everything else properly.
- **The AI sees the whole thread, both directions.** Risk in a sales
  conversation is often the *staff* side (rudeness, unauthorized promises,
  off-channel payment requests). `GET /conversations/{id}/messages` returns
  `direction: inbound|outbound`, so the transcript reads
  `Customer: … / Staff: …` in order.
- **Triggering is inbound-only** — wacrm has no outbound-message event yet.
  A risky *staff* message is therefore scored on the *next* customer reply.
  Known MVP limitation.
- The webhook answers 200 immediately (`onReceived`): wacrm delivery is
  single-attempt with a short timeout, and must never wait on the AI.

## Import & credentials (n8n Cloud)

1. n8n → Workflows → **Import from File** → `wacrm-risk-monitor.json`.
2. Credentials to attach (all import empty):
   | Node | Credential | Notes |
   |---|---|---|
   | Fetch Contact, Fetch Thread | **Header Auth** | Name: `Authorization`, Value: `Bearer wacrm_live_…` (your wacrm API key) |
   | Risk Model | OpenAI | your key |
   | Create Firestore Alert | **Google Service Account** | scope `https://www.googleapis.com/auth/datastore`, role Cloud Datastore User (see SETUP.md Part 2.2) |
3. Open **Config** node → set `wacrmBaseUrl` to the current tunnel URL.
4. Save + **Activate**. Production URL:
   `https://waseemballoul.app.n8n.cloud/webhook/wacrm-risk`

## wacrm side

1. Sign in to wacrm → **Settings → API keys → New API key**.
   Scopes needed: `contacts:read`, `conversations:read`, `messages:read`,
   `webhooks:manage`. Copy the key (shown once).
2. Register the outbound webhook (replace the key):

```bash
curl -X POST "http://localhost:3000/api/v1/webhooks" -H "Authorization: Bearer wacrm_live_YOUR_KEY" -H "Content-Type: application/json" -d "{\"url\":\"https://waseemballoul.app.n8n.cloud/webhook/wacrm-risk\",\"events\":[\"message.received\"]}"
```

   The response contains a `whsec_…` secret (shown once) — keep it; we can
   add HMAC verification to the n8n side as a hardening step later.

## The tunnel (required)

n8n Cloud must reach your local wacrm to fetch threads, and Meta must reach
it to deliver WhatsApp messages. Quick tunnel (no account needed):

```bash
C:\Users\USER\Desktop\wacrm\.tools\cloudflared.exe tunnel --url http://localhost:3000
```

It prints `https://<random-words>.trycloudflare.com`. That URL:
- goes into the n8n **Config** node (`wacrmBaseUrl`)
- becomes Meta's webhook callback: `https://…trycloudflare.com/api/whatsapp/webhook`

⚠️ The URL **changes on every cloudflared restart** — update both places when
it does. For a stable URL later: a named Cloudflare tunnel or ngrok with an
account.

## Test without WhatsApp

Simulate a wacrm delivery straight at n8n (workflow must be Active):

```bash
curl -X POST "https://waseemballoul.app.n8n.cloud/webhook/wacrm-risk" -H "Content-Type: application/json" -d "{\"id\":\"test-1\",\"event\":\"message.received\",\"occurred_at\":\"2026-07-26T09:00:00Z\",\"data\":{\"conversation_id\":\"REAL_CONV_ID\",\"contact_id\":\"REAL_CONTACT_ID\",\"content_type\":\"text\",\"text\":\"I want my money back or I call my lawyer\"}}"
```

Use real ids from wacrm (visible in the inbox URL) so the API fetches
succeed. An urgent alert should appear in the Flutter app within seconds.

## Field contract (unchanged)

Same seven fields the Flutter `Alert` model reads; `createdAt` is written as
`timestampValue` (a string would render as "Unknown time"), and `priority` is
clamped to `urgent`/`high`/`medium` so the badge never falls back to grey.
