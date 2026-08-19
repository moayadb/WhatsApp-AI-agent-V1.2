# Contracts

The interfaces between components. **Changing one side alone does not raise an
error — alerts simply stop appearing.** Any change here is a two-sided change in
a single branch.

---

## 1. `wa` → n8n analysis webhook

`POST {N8N_ANALYZE_URL}` · header `x-sanayed-secret`
Sent by `server/wa/src/ingest.ts` → consumed by `n8n/sanayed-analysis.json` ("Prepare").

```jsonc
{
  "locale": "ar|en",                  // orgs.locale — the manager's app language.
                                      // ALL model-written text comes back in it.
  "org_prompt": "string|null",        // this org's generated monitoring prompt
  "message": {
    "direction": "in|out",
    "body": "string",
    "media_type": "image|voice|audio|document|location|contact|null",
    "media_base64": "string|null",    // present for image/voice, ≤ 8 MB
    "media_mime": "string|null",      // routing key: image/* or audio/*
    "sent_at": "ISO-8601"
  },
  "contact": { "display_name": "string|null", "is_vip": bool, "agent_name": "string|null" },
  "detect_unauthorized_promise": bool,
  "detect_off_channel": bool,
  "thread": [ { "direction", "body", "media_type", "transcript", "sent_at" } ]  // oldest first, ≤ 20
}
```

**Deliberately absent:** org/conversation/message ids. The caller keeps them.

---

## 2. n8n analysis → verdict

Returned to `wa`, which clamps unknown values before use.

```jsonc
{
  "needs_attention": bool,           // false is the normal answer
  "type": "unauthorized_promise|off_channel|escalation|other",
  "severity": "urgent|high|medium|low",
  "title": "string",                 // in the conversation's language
  "insight": "string",
  "recommended_action": "string",
  "evidence": { "quote": "string" },
  "transcript": "string"             // voice transcription / image description
}
```

`transcript` is persisted to `messages.transcript` **regardless of
`needs_attention`** — it is valuable context for later analysis.

Adding a `type` requires: this list, the `alert_type` DB enum (new migration),
`AlertType` in `lib/models/alert.dart`, and the label maps in `lib/l10n/`.

---

## 3. `wa` → API alert hook

`POST /api/hooks/n8n/alert` · header `x-analyzer-secret`

```jsonc
{
  "org_id": "uuid", "conversation_id": "uuid", "channel_id": "uuid",
  "agent_id": "uuid|null", "contact_id": "uuid", "message_id": "uuid",
  "needs_attention": true,
  "type": "...", "severity": "...", "title": "...",
  "insight": "...", "recommended_action": "...", "evidence": {},
  "event_at": "ISO-8601"
}
```

The API backfills missing agent/contact/channel from `conversation_id` and
rejects a mismatch between `org_id` and the conversation's owner. Dedupe key is
`ai:{message_id}:{type}`, so n8n retries cannot double-alert.

---

## 4. API → app

`server/api/src/routes/` → `lib/services/analyzer_api.dart`

| Endpoint | Notes |
|---|---|
| `POST /api/auth/signup` \| `login` | returns `{ token, user }` |
| `GET /api/me` | `{ user, org, settings }` — drives the launch screen |
| `GET /api/onboarding` | `{ transcript, done, generated_prompt, ai_enabled }` |
| `POST /api/onboarding/message` | interview turn **and**, once `done`, a prompt-refine request |
| `PATCH /api/onboarding/prompt` | manual prompt edit, sets `prompt_source='manual'` |
| `PATCH /api/settings` | thresholds, detectors, quiet hours |
| `GET/POST /api/agents`, `/api/channels` | team and linked numbers |
| `GET /api/channels/:id/link` | poll while a pairing code is on screen |
| `GET /api/alerts`, `PATCH /api/alerts/:id` | feed and triage |
| `GET /api/dashboard/agents\|summary` | the board |
| `WS /ws?token=` | `alert.created`, `alert.updated`, `channel.status` |

Every query scopes by `org_id` from the **verified JWT**, never from the body.
That is the entire tenant boundary.

---

## 5. API/`wa` → database

Schema is `server/db/migrations/*.sql`, applied in order on API boot.

**Append-only.** Never edit an applied migration; add `000N_description.sql`.
This is the one resource every workstream touches, and append-only is what makes
parallel work safe.

Columns with non-obvious meaning:

| Column | Meaning |
|---|---|
| `conversations.awaiting_reply_since` | set on inbound when nothing pending; cleared on staff reply. The entire response-time feature. |
| `conversations.sla_alerted_at` / `cold_alerted_at` | stamped so one slow thread does not alert every sweep |
| `messages.transcript` | voice transcription or image description |
| `org_profiles.generated_prompt` | the monitoring prompt — the product's real configuration |
| `org_profiles.prompt_source` | `llm` \| `script` \| `manual` |
| `channels.status` | `new/pairing/connected/syncing/disconnected/logged_out/error` |
| `wa_auth_state` | Baileys credentials. **Deleting a row unlinks that number.** |

---

## 6. API ↔ n8n intake workflow

`POST {N8N_INTAKE_URL}` · header `x-sanayed-secret`
Sent by `server/api/src/intake.ts` → consumed by `n8n/sanayed-intake.json`.

Request:

```jsonc
{
  "locale": "ar|en",
  "transcript": [ { "role": "assistant|user", "text": "string" } ],
  "mode": "interview|refine",
  "current_prompt": "string|null"      // the prompt being edited, in refine mode
}
```

Response:

```jsonc
{
  "reply": "string",                   // what the manager reads
  "done": bool,
  "generated_prompt": "string|null",   // complete prompt; null unless done
  "topics": ["string"],                // 3-6 short labels, manager's language
  "thresholds": { }                    // only numbers the manager stated
}
```

`topics` is what the **app shows**; `generated_prompt` is stored but never
displayed to the user. Both are regenerated whenever the prompt changes.

---

## 7. Ownership map

Suggested split for parallel work. Anything in the "shared" row needs
coordination.

| Workstream | Owns | Must not change alone |
|---|---|---|
| WhatsApp ingestion | `server/wa/` | contracts 1, 2, 3 |
| Backend & detectors | `server/api/` | contracts 3, 4, 5 |
| AI workflows & prompts | `n8n/` | contracts 1, 2 |
| App | `lib/`, `web/` | contract 4 |
| Deployment | `server/docker-compose.yml`, `Caddyfile`, `deploy.sh`, `run-local.ps1` | — |
| **Shared** | `server/db/migrations/` (append-only), `docs/` | — |

---

## Migration ledger

Numbers are allocated by the consultant so two streams cannot claim the same one.

| Number | Owner | Purpose | Status |
|---|---|---|---|
| `0001_init.sql` | — | initial schema | applied |
| `0002_intake_prompt.sql` | — | generated prompt columns | applied |
| `0003_prompt_topics.sql` | Product | `org_profiles.prompt_topics jsonb NOT NULL DEFAULT '[]'` | allocated |
