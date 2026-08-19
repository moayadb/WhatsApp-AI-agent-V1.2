# Multi-Channel AI Analyzer

WhatsApp conversation monitoring for sales teams. It watches a team's WhatsApp
threads and alerts the manager **only when their personal intervention is
required** — an unanswered lead, a conversation going cold, a staff member
promising something the company cannot honour, a client being moved off the
company channel.

Target user: Faisal, a Dubai real-estate sales manager with ten agents, each on
their own number. Success is defined as never having to ask "did you follow
up?" at the Sunday meeting.

## Read these before changing anything

| File | Why |
|---|---|
| `docs/DECISIONS.md` | Environment traps that cost days to find. **Read first.** |
| `docs/CONTRACTS.md` | Interfaces between components. Breaking one fails silently. |
| `docs/RUNBOOK.md` | How to start, verify, back up and deploy. |

`PROJECT_STATE.md`, `PROJECT_KNOWLEDGE_BASE.md` and `BUSINESS_ADVISOR_CONTEXT.md`
describe the **superseded Firebase version** of this product. They are kept for
business context only. Do not treat them as current architecture.

## Shape of the system

```
WhatsApp ⇄ wa (Baileys)  ──→ n8n workflow ──→ OpenAI ──→ verdict
                │                                          │
                ▼                                          ▼
            Postgres  ←──────────────  api (REST + WebSocket + worker)
                                              │
                                              ▼
                                      Flutter app (web / iOS / Android)
```

| Component | Path | Responsibility |
|---|---|---|
| WhatsApp service | `server/wa/` | Baileys sessions, pairing, message ingestion, media download |
| API | `server/api/` | Auth, alerts, onboarding, settings, timer detectors, WebSocket |
| AI workflows | `n8n/` | Intake interview + message analysis (prompts live here) |
| App | `lib/` | Flutter client, Arabic-first RTL |
| Schema | `server/db/migrations/` | Append-only SQL migrations |

## Rules that keep parallel work safe

1. **Migrations are append-only.** Never edit an applied migration; add a new
   numbered file. This is the only genuinely shared resource.
2. **Contract changes are two-sided, in one branch.** Changing the verdict JSON
   or an API response means changing both sides together — see
   `docs/CONTRACTS.md`. A mismatch does not error; alerts just stop appearing.
3. **Rebuild `dist/` in BOTH places.** `npm run build` on Windows for the native
   stack AND `docker compose build` for the container stack. Verifying in one
   while running the other has already cost a full debugging round.
4. **Never commit secrets.** `server/.env*`, `server/.secrets.local` are
   gitignored. The n8n JSON files carry `__N8N_WEBHOOK_SECRET__` as a
   placeholder — substitute at import time, never commit the real value.
5. **Do not "fix" the things in the DO NOT UNDO list** in `docs/DECISIONS.md`.
   Several look like bugs and are deliberate.

## Where the AI lives

Two separate AI roles, deliberately not the same thing:

- **Interviewer** (`n8n/sanayed-intake.json`) — interviews the manager and
  *writes* the monitoring prompt for their business. Also handles later
  "also alert me when…" edit requests.
- **Analyst** (`n8n/sanayed-analysis.json`) — reads each WhatsApp message using
  *that generated prompt* and decides whether the manager must step in.

The generated prompt is stored per-org in `org_profiles.generated_prompt` and is
the product's real configuration surface. The manager can see and edit it.

Timer-based detection (unanswered lead, cold lead) is **pure SQL in the API
worker** and deliberately involves no model — it must work when OpenAI is down.
