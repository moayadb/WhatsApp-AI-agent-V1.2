# Worklog — pipeline

Owner: the pipeline engineer (server/wa/ and n8n/).
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

### 2026-08-19 — AI output language follows the manager's locale; intake returns topics
Done:      Both workflows are updated and saved on the live n8n instance, and
           all seven live scenarios pass. Results at the bottom of this entry.

           TASK 1. `server/wa/src/ingest.ts` now joins `orgs` in the analysis
           meta query and sends `locale` (clamped to ar|en, default ar) at the
           top of the contract-1 payload. In `sanayed-analysis.json`, `Prepare`
           passes the locale through, `Build messages` names the exact fields
           the model must write in that language — title, insight,
           recommended_action, plus media_description for images and
           transcript_translation for voice — and `Shape verdict` composes the
           stored transcript.

           Voice notes, the judgement call you asked for: Whisper is NOT told
           what language to expect, so the transcription stays faithful to what
           was actually spoken. The manager's language is applied to the
           summary instead. When the spoken language differs from his, the
           model returns a translation and `Shape verdict` stores
           `verbatim + "\n\n" + الترجمة: …` in the one `messages.transcript`
           field. Rationale: `evidence.quote` is only worth anything if it
           matches the real chat word for word, so the verbatim text has to
           survive — but an Arabic-only manager cannot read an English client,
           so the translation has to be there too. Both, in one field, because
           contract 2 has one field. If you would rather have a separate
           column, that is a migration and therefore your call.

           I also told the model explicitly NOT to translate `evidence.quote`.
           Without that line, an instruction to write everything in Arabic
           takes the quote with it, and the evidence stops matching the chat.

           TASK 2. `sanayed-intake.json` returns `topics` in both modes.
           `Shape response` gates them on `done` exactly like
           `generated_prompt` (so a mid-interview turn returns `[]`), trims,
           collapses whitespace, dedupes case-insensitively and caps at 6.
           Refine mode is told to derive topics from the whole updated prompt,
           not just the rule that changed, so they never drift out of sync.

           Verified: 40/40 checks running the five patched Code nodes with n8n's
           globals mocked — locale clamping, routing, prompt wording, transcript
           composition in all four language combinations, topic shaping.
           `npm run build` clean in `server/wa`.

           Baseline against the LIVE analyse webhook (old code) reproduces the
           bug and is worse than reported: with locale=ar and no text to infer
           from, the image description came back in **Spanish**, not English.
           Audio and text both came back English. Kept as the "before".

           LIVE RESULTS — analysis, before → after

           image, locale=ar, no caption, empty thread:
             before  description in SPANISH: "Imagen de un recibo de pago…"
             after   "صورة لإيصال دفع يوضح دفع مبلغ 50,000 درهم لوحدة رقم 1204…"
                     evidence.quote stayed the verbatim English on the image.
           voice note (English speech), locale=ar:
             before  title/insight/action all English
             after   all Arabic; transcript = English verbatim +
                     "\n\nالترجمة: …"; evidence.quote verbatim English.
           text (English message, Arabic thread), locale=ar:
             before  all English
             after   all Arabic, evidence.quote verbatim English.
           text (Arabic message), locale=en:
             after   all English, evidence.quote verbatim Arabic.

           That last one is the one I would keep: locale wins in BOTH
           directions, so it is genuinely following the manager's setting and
           not just agreeing with the conversation by luck.

           LIVE RESULTS — intake

           mid-interview   done=false, topics=[]  (suppressed, as designed)
           finished        done=true, 949-char prompt, 5 Arabic topics:
                           وعود غير معتمدة · نقل العميل خارج القناة ·
                           عملاء غاضبون يهددون · عملاء مهمون · تأخر الرد
           refine          added "ألفاظ غير لائقة" AND kept the other five —
                           regeneration covers untouched rules, not just the
                           changed one.

           Threshold discipline held: it returned first_response_minutes=15,
           the number the manager actually typed, and did not invent one from
           the failure story.

Question:  1. Contract 2 still describes `title` as "in the conversation's
              language". Contract 1 now says all model-written text comes back
              in `locale`. The code follows contract 1. `docs/` is shared so I
              have not touched it — want me to fix that line, or will you?

           2. On the finishing turn the interviewer also returned
              `alert_after_no_reply_minutes: 60`, because the manager said
              "إذا ما رد خلال ساعة أبي أعرف". That key is not in contract 6,
              and `routes/onboarding.ts` builds its patch only from
              `first_response_minutes` / `cold_lead_hours`, so it is dropped
              silently — no crash, nothing written. Benign, but the manager
              explicitly asked for something and it evaporates. Three ways out:
              add the key to contract 6 and the settings, fold it into
              `cold_lead_hours`, or tell the interviewer to stop emitting it.
              Your call — it spans contract 6 and the API, so not mine alone.

Heads-up:  `server/wa/dist/` is rebuilt (native Windows). The container image is
           NOT — `docker compose build` needs the WSL daemon and it refuses the
           socket from this shell (permission denied). Per rule 3 in CLAUDE.md
           the container stack still holds the old `wa` code, so whoever
           deploys must rebuild it or the locale field will not be sent.

           `messages.transcript` for a voice note may now hold two blocks
           (verbatim, then a labelled translation) instead of one. Whoever
           renders it in the app should expect a newline, and the label is
           Arabic or English depending on the org's locale. No schema change.

           `Shape response` caps a topic label at 60 chars to match
           `sanitizeTopics()` in `server/api/src/intake.ts`. If you change one,
           change the other, or labels get clipped on the way through.

           Separately, four defects I found while reading and have NOT touched,
           all in my lane, none related to the two tasks above:

           1. `normalize()` in `server/wa/src/ingest.ts` reads `msg.message`
              raw, so WhatsApp's `ephemeralMessage` (disappearing messages),
              `viewOnceMessageV2` and `documentWithCaptionMessage` wrappers all
              fall through to the final `else` and the message is dropped
              entirely — no row, no response clock, no analysis, nothing
              logged, `channels.status` still `connected`. Baileys exports
              `normalizeMessageContent` for exactly this. A client turning on
              disappearing messages silences that thread completely. This is
              the one I would fix first.
           2. `attachMedia()` in `sessions.ts` has the same raw-`message` read,
              so for a wrapped image the 8 MB cap stops being enforced and
              `media_mime` goes null — and `media_mime` is what the analysis
              workflow routes on, so a wrapped image would be judged as text.
           3. `Transcribe voice` has no `onError`/retry: one failed Whisper
              call fails the whole run, so `Respond` never fires and the
              message gets neither transcript nor verdict. It should continue
              with an empty transcription instead.
           4. `wa` treats the documented empty-200-on-rejected-secret as a
              generic failure, so a wrong `N8N_WEBHOOK_SECRET` looks identical
              to a model timeout in the log.

           Want these as one batch, or in that order one at a time?
