# Worklog — product

Owner: the product engineer (server/api/ and lib/).
Reader: the consultant. This is the only channel between us — separate
conversations cannot see each other.

Append newest entries at the TOP. Keep entries short. Only this stream writes
to this file, so it can never conflict with the other engineer's worklog.

Use it for three things:

- **Done** — what changed and why, when a commit message alone is not enough
- **Question** — anything you want the consultant to decide, especially a
  contract change (docs/CONTRACTS.md) or a new database migration
- **Heads-up** — something the other stream will notice, or a trap worth
  adding to docs/DECISIONS.md

---

## Template

```
### YYYY-MM-DD — short title
Done:      what you changed, and the commit hash if there is one.
Question:  what you need the consultant to answer, if anything.
Heads-up:  anything the other stream or the runbook should know.
```

---

### 2026-08-19 — language reaches the server; Settings shows topics, not the prompt

**Done**

*Task 1 — locale.* `PATCH /api/settings` now accepts `locale` and writes it to
`orgs.locale`. Settings switches the app language from the device preference
first (instant, offline) and tells the server after; if that call fails the
manager gets a snackbar saying alerts may keep arriving in the old language,
rather than discovering it a week later. Signup also sends the locale now, so
the first alert is in the right language before he has opened Settings.

*Task 2 — topics.* Migration `0003_prompt_topics.sql` adds
`org_profiles.prompt_topics jsonb NOT NULL DEFAULT '[]'`. `generated_prompt` no
longer leaves the server: `GET /api/onboarding` and `POST /api/onboarding/message`
return `topics` instead. Settings shows chips plus one action that opens a new
conversation screen (`lib/screens/refine_screen.dart`), which opens on "ما الذي
تريد تعديله في محرك الذكاء الاصطناعي؟" and posts to the existing refine flow.
The end-of-interview screen shows the same chips. The manual prompt editor is
gone from the UI; `PATCH /api/onboarding/prompt` stays and now takes an optional
`topics` so a hand-fixed prompt does not leave the manager reading labels for
rules that no longer exist.

Empty topics are handled as "not written yet", never as "watching nothing": the
API keeps existing labels when a refine turn returns none, and the screen says
so in words.

**Verified.** Migration applies; locale round-trips through `/me`; language-only
PATCH returns the settings row instead of 400; a live n8n interview turn and a
live refine turn both come back with no `generated_prompt` and with existing
topics intact. Ran against the dev database on a temporary API on :3001 so your
running stack was untouched; the test org was deleted afterwards.
`flutter analyze` is clean. The Flutter UI itself is **not** visually verified —
a canvas app does not composite in my environment, so the chips and the refine
screen have been type-checked but not looked at.

**Question**

1. I committed two files outside `server/api` and `lib`: the allocated
   `0003_prompt_topics.sql` and this worklog. Both look intended, but say if not.
2. Contract 4 moved on both sides in this branch: `PATCH /api/settings` takes
   `locale`; the two onboarding endpoints return `topics` instead of
   `generated_prompt`; `PATCH /api/onboarding/prompt` takes optional `topics`.
   `docs/` is shared — do you want me writing that into `CONTRACTS.md`, or you?
3. On a new device the app defaults to Arabic even when `orgs.locale` is `en`,
   and never corrects itself because only an explicit change PATCHes. Should the
   app adopt `org.locale` at login when the device has no stored choice?
4. Still open from the read-in: `slaSeverity()` in `worker.ts` returns `urgent`
   for both `>= threshold * 4` and `>= threshold * 2` — deliberate placeholder,
   or should the ×4 case become something louder?

**Heads-up**

- The native API on :3000 is still running the pre-change build. `dist/` is
  rebuilt, so it only needs a restart. Migration 0003 is already applied to the
  local database.
- **The Docker image was not rebuilt** (CLAUDE.md rule 3). `docker` in WSL wants
  an interactive sudo password here, so the container stack is still on the old
  code and will need `docker compose build` before it is trusted.
- For the pipeline stream: a refine turn sent with `locale: "en"` and an English
  message came back in Arabic from the live intake webhook. Contract 6 says
  `locale` travels with the request, so the refine branch may be ignoring it.
- `prompt_topics` defaults to `[]` and the API never blanks a non-empty list, so
  topics can start arriving from the workflow whenever they are ready — nothing
  on my side needs to change when they do.
- l10n: removed `promptLoadFailed` and `editAction` (now unused); added
  `topicsPending`, `topicsLoadFailed`, `refineAction`, `refineTitle`,
  `refineOpeningLine`, `languageSyncFailed`.
