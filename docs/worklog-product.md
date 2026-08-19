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

### 2026-08-20 — UX correctness round (A1–A3, B1–B4, C1–C6)

**A1 — topics can no longer lie about the prompt.** All writes to
`generated_prompt` now go through `savePrompt()` in `server/api/src/prompt.ts`;
no route touches the column directly any more. Topics that came from the same
conversation turn are used as-is; anything else (the manual PATCH, the backfill)
asks the workflow with `mode: "topics"`. A failed generation writes the prompt
and keeps the previous labels — enforced in SQL with
`COALESCE(NULLIF($4,'[]'), prompt_topics)`, so even a bug upstream cannot empty
the screen. Backfill: `npm run backfill:topics` in `server/api`, idempotent, only
touches rows that still have none.

**A2 — timer alerts speak the manager's language.** `worker.ts` joins
`orgs.locale` and writes title/insight/action from a per-language table; that
text is what the push notification carries. The app ignores it for `sla_breach`
and `cold_lead` and rebuilds the line from `evidence`, so the display follows the
app language even when the org locale changed after the alert was written. I
also rebuild the *title* for those two types, not just the insight — agent and
client come from the join, so it is the same data, and a card with an Arabic
headline over an English body was the thing that looked broken.

**A3 — placeholder.** "أُنشئ بدون نموذج ذكاء اصطناعي" now appears only when
`ai_enabled` is false. Empty topics with a prompt present get `topicsPending`.

**B1** Handled is instant with an undo snackbar (undo goes through the API —
`AlertsProvider.undoStatus` works on an id, because the row has usually left the
filtered list by then). Ignore asks first. Done/ignored cards render at 55%
with a neutral type badge. **B2** The filter bar is a `Wrap`, not a 52 px row —
that height was cutting the descenders off "يحتاج تدخّلك". **B3** The red banner
is now a card: tapping it scrolls to the broken number and highlights it for
three seconds, and it carries a reconnect button. **B4** A board row for an
unmonitored agent shows why there is no data plus a connect/reconnect button,
instead of five zeros that read as a perfect week.

**C1** IBM Plex Sans Arabic bundled in `assets/fonts/` (OFL, licence included),
set as the app family with a Latin fallback — it covers both scripts, so a
mixed name/number line is one typeface. Nothing is fetched at runtime. Swept the
screens: every `style:` in `lib/` now derives from the text theme; the one
literal `TextStyle` left (the filled-button style) was silently falling back to
the platform font and is fixed. **C2** Sun/moon toggle in the app bar with an
animated swap and an Arabic tooltip; Settings keeps "حسب الجهاز" as a single
switch. **C3** `رقمي` instead of "رقم غير مُسنَد" wherever a channel has no
agent — app and worker both. **C4** A channel label equal to the agent's name is
suppressed. **C5** `bidiIsolate()` (FSI/PDI) around names, phone numbers and the
pairing code; `AutoDirectionText` on insights, recommended actions and thread
bubbles. **C6** One line under the banner saying what to do, on which phone.

**Verified**

- A2 end to end: fixtures in an `ar` org and an `en` org, 90 minutes past a
  15-minute threshold, worker sweep on boot. Arabic org →
  «خالد لم يرد على عميل الاختبار / في الانتظار منذ 90 دقيقة — الحد المسموح 15 دقيقة».
  English org → "My number has not replied to Test Client / Waiting 90 min —
  threshold is 15 min." Same data, language decided by `orgs.locale`.
- A1 failure path: `PATCH /onboarding/prompt` with a completely different prompt
  → prompt written, `prompt_source` `manual`, topics **unchanged**; log shows the
  `mode: "topics"` call was attempted. Explicit topics are accepted, trimmed and
  deduped.
- Backfill run against the dev database: **`{"scanned":6,"filled":0,"failed":6}`**
  — see the pending note below. Re-checked after: 6 still need topics, nothing
  was blanked.
- `flutter test` — 11 new tests pass, covering the A2 language rule, the
  evidence fallback, `رقمي`, Arabic filter chips rendering without overflow, the
  topics empty-state copy, and the isolate helpers. One of them caught a wrong
  assumption in my own test, not in the code.
- `flutter analyze`: 4 issues, all pre-existing `prefer_initializing_formals` in
  `auth_provider.dart`. The lint's suggested fix is not expressible — Dart
  forbids private named parameters, so `required this._client` will not compile.
  I left them rather than papering over them with an ignore.
- Web bundle rebuilt; the font is in `FontManifest.json` and serves from our own
  origin (200, 235924 bytes).
- **Not verified: the screens themselves.** A Flutter canvas does not composite
  in my environment, so B1–B4 and C1–C6 are type-checked, unit-tested where a
  headless test can reach, and unseen. The typography and the highlight
  animation in particular want your eyes.

**Question**

1. **A1 is built but not provably working**: `mode: "topics"` is not live yet on
   n8n — I probed the webhook and it answered with an interview question and
   `topics: []`. There is no `LLM_API_KEY` in `server/.env.local` either, so the
   direct-LLM fallback cannot cover for it. **The backfill is therefore pending:
   re-run `npm run backfill:topics` once the pipeline half is deployed.** The
   6 affected orgs keep working meanwhile — they just show "قيد الإعداد".
2. Paths again: this commit also touches `assets/fonts/`, `pubspec.yaml` (the
   font declaration cannot live under `lib/`), `test/`, and this worklog. All
   unambiguously mine, but outside `git add server/api lib`.
3. Contract 4 drift is now three rounds deep and `docs/CONTRACTS.md` still
   describes the old shapes. Want me to write it, or will you?
4. Still open from earlier rounds: the `slaSeverity()` ×4 branch, and whether a
   new device should adopt `org.locale` when it has no stored choice.

**Heads-up**

- The API on :3000 and the web on :8081 are both running **older code**.
  `server/api/dist` and `build/web` are rebuilt; both need a restart, and the
  new bundle on 8081 will be talking to the old API until you do.
- Docker image still not rebuilt (rule 3) — same sudo wall as last round.
- Test data: created two fixture orgs and one signup org, then deleted all
  three. `orgs` back to 8, `wa_auth_state` untouched at 261 rows throughout.
- `myNumberLabel` replaces `unassignedAgent` in `lib/l10n/` — if the pipeline
  stream references that key anywhere, it is gone.
- New npm script: `npm run backfill:topics` in `server/api`.

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
