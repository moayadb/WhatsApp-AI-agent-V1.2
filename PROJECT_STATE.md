# PROJECT_STATE.md — Sanayed (سانايد)

> **Purpose of this file.** Core memory and context guide for development
> sessions. Organised by **feature**, not by technical layer. Update it when a
> feature's behaviour, data contract, or platform configuration changes.
>
> Last verified against the codebase at commit `942fe45`.

---

## 1. Project Overview

**Sanayed** turns a company's WhatsApp conversations into an actionable
operations feed for managers.

An external **n8n workflow** consumes incoming WhatsApp messages (text, images,
voice notes), analyses each one with an AI agent, and writes **one Firestore
document per analysed message**. This Flutter app is the **read-mostly front
end** over that stream.

What it does for the user:

- Surfaces messages the AI flagged as needing human attention (complaints,
  refund demands, delivery failures, legal threats, VIP issues) as a
  prioritised, filterable alert queue.
- Lets a manager triage each alert — mark done, ignore, or revert — with
  handling time recorded for performance measurement.
- Reports on the whole stream: escalation rate, workload over time, peak
  hours, department load, repeat customers.

**The app never writes alert content.** It reads, and it writes exactly one
field pair (`status` + `completion_date`).

**Primary audience:** business owner, sales manager, operations/purchasing
manager. **Primary language: Arabic (RTL)**, English secondary.

---

## 2. Tech Stack & Architecture

### Core technologies

| Concern | Choice |
|---|---|
| Framework | Flutter 3.44.x / Dart 3.12.x |
| State management | **`provider`** (`ChangeNotifier`) — used consistently, no other approach |
| Backend | **Cloud Firestore** (`cloud_firestore`) — single collection `alerts` |
| Auth | **Firebase Auth** — email/password behind a username field, gated by a Firestore allowlist |
| Charts | `fl_chart` |
| Localisation | `flutter_localizations` + `intl` + ARB files (`gen-l10n`) |
| Relative time | `timeago` (ar + en registered at startup) |
| Local prefs | `shared_preferences` |
| Audio | `audioplayers` (in-app alert chime) |
| Export | `excel`, `pdf`, `printing`, `share_plus`, `http` |
| Ingestion | **n8n** (external) → Firestore. The app never talks to n8n or WhatsApp. |

### Data flow

```
WhatsApp ──► n8n workflow (AI analysis) ──► Firestore `alerts`
                                                  │
                                    ┌─────────────┴─────────────┐
                        AlertsProvider                DashboardProvider
                     (needs_attention only)          (every analysed doc)
                                    └─────────────┬─────────────┘
                                             Flutter UI
```

### Provider topology — important

There are **exactly two Firestore subscriptions**, both created above the
navigation shell in `main.dart` and started once when `MainShell` mounts. Never
open a listener inside a screen.

| Provider | Query | Why separate |
|---|---|---|
| `AlertsProvider` | `where('needs_attention', ==, true).orderBy('message_at', desc).limit(200)` | The action queue |
| `DashboardProvider` | `orderBy('created_at', desc).limit(500)` — **no** `needs_attention` filter | Ratios like escalation rate are impossible without the non-alert messages |

Both share **one** `AlertsService` instance (two differently-scoped queries on
the same collection).

### Folder structure

```
lib/
  main.dart                 App bootstrap, MultiProvider, auth gate (_Root)
  firebase_options.dart     Generated — web + android + ios
  models/
    alert.dart              Alert + 6 enums, defensive fromFirestore
    app_user.dart           AppUser, UserRole → default department
  services/                 Everything that touches the outside world
    alerts_service.dart     The only Firestore access
    auth_service.dart       AuthService interface + FirebaseAuthService
    export_service.dart     Excel / PDF / capture / share / email POST
    notification_sound.dart In-app chime
  providers/                State + orchestration
    alerts_provider.dart    Alert stream, filters, optimistic writes
    dashboard_provider.dart Analytics stream, own filters, DashboardMetrics
    auth_provider.dart      Sign-in state, error codes
    settings_provider.dart  Theme + locale
  screens/
    login_screen.dart       Username + password form
    main_shell.dart         One Scaffold, AppBar, NavigationBar
    alerts_tab.dart         List + filter chips + Excel export
    alert_detail_screen.dart Detail, confirmations, revert
    dashboard_tab.dart      All charts + PDF export (largest file, ~1100 lines)
    settings_tab.dart       Account, theme, language, sound, sign out
  widgets/                  Reusable UI
  theme/app_theme.dart      Colours, light/dark, priority colour map
  l10n/                     app_ar.arb, app_en.arb, labels.dart, generated/
test/                       alert_model_test.dart, dashboard_metrics_test.dart,
                            auth_username_test.dart
n8n/                        Workflow JSON + setup docs (not app code)
```

**Convention:** models are framework-free (no Flutter imports) so they stay
unit-testable. UI concerns like priority colours live in `theme/`.

---

## 3. Feature-Based Breakdown

### 3.1 Authentication & Access Control

**Purpose.** Restrict the app to a known set of staff, without running a user
database. Staff sign in with a **username and password**; the allowlist decides
who gets to keep the session.

**UI components**
- `screens/login_screen.dart` — one form, two fields (username, password) with
  a show/hide toggle. No signup, no password reset, no account management.
- `_ErrorLine` — inline error with reserved space so the form never jumps
- `main.dart` → `_Root` — auth gate: restoring splash → login → `MainShell`

**Business logic**
- `providers/auth_provider.dart` — `signIn`, `busy`, `errorCode`
  (`invalid_credentials` / `not_allowed` / `too_many_attempts` /
  `sign_in_failed`)
- `services/auth_service.dart` — `AuthService` abstraction +
  `FirebaseAuthService`. Swapping the mechanism touches this file only.

**The username is a UI convenience, not a separate identity.**
Every account is an ordinary Firebase Auth email/password user whose address is
`<username>@sanayed.app`. `FirebaseAuthService.emailForUsername` does the
mapping (trim → lowercase → append domain); staff never see or type the domain.
`sanayed.app` is **synthetic** — no mailbox exists behind it, which is exactly
why there is no password reset or email verification in the app. Accounts are
created, and passwords reset, **by hand in the Firebase Console**.

**Credentials live only in Firebase Auth.** No username or password exists in
Dart, and the app performs no local comparison of any kind — it hands both
values to `signInWithEmailAndPassword` and reports what Firebase says.

**Data & integrations**
- Firestore **`allowed_users`** — document ID is the **lowercase email**;
  fields `email`, `role` (`owner` | `sales` | `purchasing`), `added_at`.
  The `email` field must now hold the **synthetic** address
  (`waseem@sanayed.app`), because that is what the account authenticates as.
- Firestore **`admins/{uid}`** — referenced by rules for allowlist writes.
- Firebase Auth: **Email/Password provider must be enabled** in the console.

**Behaviour worth knowing**
- **Gatekeeper runs after authentication**, the same way the old Google flow
  worked: Firebase mints the session, then `allowed_users` is checked, and a
  non-listed account is signed straight back out. An allowlist read that
  *fails* also signs out — failing open would leave an unvetted account holding
  a live session.
- **Wrong username and wrong password are indistinguishable.** Firebase's
  `invalid-credential` / `user-not-found` / `wrong-password` / `invalid-email`
  all map to one message, so a wrong guess cannot be used to discover which
  usernames exist.
- `user-disabled` maps to "not authorized" rather than "wrong password" —
  disabling an account in the console is the fast way to revoke access, and the
  user should not be told to retype a password that is in fact correct.
- `restoreSession` does **not** re-check the allowlist. Removing someone from
  `allowed_users` does not end a session already on a device; disable the
  account in Firebase Auth to cut it off immediately.
- `role` seeds the default department filter on **both** tabs. It is a
  convenience default, **not** a security boundary — any user can widen it.

**✅ The tester bypass is gone.** `BYPASS_CODE`, `bypass_session` and the local
`_bypassUser` were deleted outright; there is no longer any code path to a
session that did not come from Firebase.

---

### 3.2 Alerts System (triage queue)

**Purpose.** Present flagged messages newest-first and let a manager act.

**UI components**
- `screens/alerts_tab.dart` — filter chips (department / priority / status),
  skeleton loading, empty state, pull-to-refresh, export menu
- `widgets/alert_card.dart` — priority badge, relative time, `summary` headline,
  sender + category. Non-new alerts dim rather than disappear.
- `screens/alert_detail_screen.dart` — badges, sender block, message bubble,
  AI analysis panels, actions
- `widgets/badges.dart` — `PriorityBadge`, `CategoryBadge`, `StatusBadge`,
  `PhoneText` (forces LTR)
- `widgets/auto_direction_text.dart` — per-string direction detection
- `widgets/states.dart` — `EmptyState`, `SkeletonList`

**Business logic**
- `providers/alerts_provider.dart` — stream, client-side filters, optimistic
  `setStatus`, `effectiveStatus`, arrival detection for the chime
- `services/alerts_service.dart` — `watchAlerts`, `fetchOnce`, `updateStatus`

**Data & integrations**
- Firestore `alerts`, filtered to `needs_attention == true`
- Writes **only** `status` + `completion_date`

**Message bubble rules (easy to regress — see §5)**
- Renders **`display_text`**, never `summary`. `summary` is the card/detail
  title only.
- A source badge is always shown, derived from `display_source`:
  `customer_message` → رسالة العميل · `audio_transcript` → تحليل رسالة صوتية ·
  `image_description` → تحليل صورة
- For image/audio with a distinct caption, `message_content` renders as a
  separate "تعليق العميل" line.
- Empty text shows a muted "لا يوجد نص" placeholder.

**Status lifecycle**
- Confirmation dialog before every transition (done / ignore / revert).
- Once resolved, action buttons are replaced by `_ResolvedPanel` showing the
  outcome, completion time, and an **undo**.
- `done` stamps `completion_date` with `FieldValue.serverTimestamp()`; any
  other status **clears it to null** so handling-time stats never count a
  stale stamp.
- Optimistic UI: instant dim + snackbar; rollback + error on failure.

---

### 3.3 Monitoring Dashboard

**Purpose.** Answer "how much traffic, how much of it is a problem, when does
it arrive, who is causing it" — over the whole analysed stream, not just alerts.

**UI components** — all in `screens/dashboard_tab.dart`:
- Filters: date range segmented control (today / 7d / 30d / all) + department +
  priority chips, independent of the alerts-tab filters
- 4 headline metric cards: messages analysed · alerts · **escalation rate** ·
  open backlog
- Workload: escalation split bar · stacked volume over time · peak-hours histogram
- Breakdown: priority mix (incl. low) · department load bars · category donut ·
  handling status · message-type mix
- Customers: unique, repeat, top alert-raisers
- Everything inside a `RepaintBoundary` (`_reportKey`) for PDF capture; the
  filter controls sit **outside** it

**Business logic**
- `providers/dashboard_provider.dart` — own subscription, own filters,
  `DashboardMetrics.from(...)` computes every number in one pass
- `DashboardStats` in `alerts_provider.dart` is a **legacy** aggregate still
  used by the older code path; `DashboardMetrics` is the current one

**Data & integrations**
- Firestore `alerts`, **unfiltered** (`orderBy('created_at')`), limit 500
- Zero extra reads for any chart — all computed in Dart

**Why `created_at` for ordering:** Firestore drops documents missing the
`orderBy` field. Only ~19 of 33 documents in the live collection had
`message_at`; ordering on it silently skewed every metric. Day/hour bucketing
still prefers `message_at` via `Alert.timeAt`.

---

### 3.4 Notifications (in-app sound)

**Purpose.** Audible cue when a new alert arrives while the app is open.

**UI / logic**
- `services/notification_sound.dart` — singleton, `audioplayers`, never throws
- `assets/sounds/new_alert.wav` — generated two-tone chime
- Fired from `AlertsProvider`'s stream listener: only for document IDs **not
  seen in the first snapshot**, so a cold start never plays a burst
- Toggle in `settings_tab.dart`; enabling plays a preview, which also satisfies
  browsers' requirement for a user gesture before audio

### 3.4b Push Notifications (receive side only)

**Purpose.** Reach a manager when the app is closed — the chime above cannot.

**⚠️ Not deliverable yet. The send side does not exist.** The app can receive;
nothing writes to FCM when an alert document is created. Until n8n (or a Cloud
Function) makes that call, no notification will ever arrive no matter how
correct the client is.

**Why a server has to send it.** iOS forbids a closed app from polling
Firestore; background fetch is throttled far below alert latency. APNs is the
only door to an iPhone, and only a server can knock on it.

**UI / logic**
- `services/push_service.dart` — permission prompt, token retrieval, token
  refresh, token storage, unregister. Never throws; push is a convenience on
  top of the alerts stream.
- Registration hangs off `AuthProvider` (a token is only useful while a session
  exists), on both `signIn` and `restore`.
- Foreground is deliberately left to the existing chime. iOS shows no banner
  for a foreground message unless asked, and asking would double-alert.

**Data**
- Firestore **`device_tokens/{deviceId}`** — `token`, `email`, `platform`,
  `updated_at`. `deviceId` is a random per-install id in `shared_preferences`,
  **not** the FCM token: tokens rotate, and one row per install means rotation
  updates rather than accumulates.
- Rules: a client may only write a row carrying **its own** email, and **no
  client may read the collection**. The sender uses a service account, which
  bypasses rules entirely.

**Sign-out order matters.** `AuthProvider.signOut` unregisters *before*
`_service.signOut()`. The `device_tokens` rule needs an authenticated caller,
so the reverse order is rejected and leaves the phone still receiving.

**iOS configuration — the classic trap**
- Two entitlements files, wired per build config in `project.pbxproj`:
  `Runner.entitlements` (`aps-environment: development`) for Debug/Profile,
  `RunnerRelease.entitlements` (`production`) for Release.
- A single file for both is the "push works from Xcode, silently never arrives
  on TestFlight" bug: the token registers against the wrong APNs environment
  and Apple drops every send **without an error**.
- `UIBackgroundModes: remote-notification` in `Info.plist`.
- Push Notifications capability enabled on App ID `com.sanayed.tulipAlerts`
  (Team ID `65FV7479DB`). **This invalidated the existing provisioning
  profiles** — they must regenerate before Codemagic can sign a build.

**What the sender must POST** — FCM HTTP v1, one request per token:

```
POST https://fcm.googleapis.com/v1/projects/whatsapp-ai-agent-waseem/messages:send
Authorization: Bearer <OAuth2 token from a service account>

{"message": {
  "token": "<one token from device_tokens>",
  "notification": {"title": "تنبيه جديد", "body": "عاجل · المبيعات"},
  "apns": {"payload": {"aps": {"sound": "default"}}},
  "data": {"alert_id": "<doc id>", "priority": "urgent"}
}}
```

A `notification` block is required — iOS renders it with no app code. A
data-only payload shows nothing and would need a background handler the app
does not have. **Do not put customer message text in `body`**; it lands on the
lock screen. Priority + department only.

**Status — verified 2026-08-02**

| Piece | State |
|---|---|
| Push capability on App ID `com.sanayed.tulipAlerts` | ✅ enabled |
| APNs auth key `GJG9V6X7B2` (Team Scoped, **Sandbox & Production**) | ✅ created |
| Key uploaded to Firebase — **both** dev and prod rows, Team `65FV7479DB` | ✅ |
| FCM API (V1) | ✅ enabled |
| `device_tokens` Firestore rule | ✅ deployed |
| n8n send branch (4 nodes) + service-account credential | ✅ wired |
| **Three password accounts in Firebase Auth** | ❌ **not created** |
| Branches merged / build shipped | ❌ |

**The APNs environment trap, for the record.** The first replacement key was
created as **Sandbox only** because Apple's create-key flow defaults that way
unless you click *Configure* next to the APNs checkbox. A Sandbox-only key
cannot reach production APNs, which is what TestFlight builds use — FCM returns
HTTP 200 and Apple discards the send with no error anywhere. Always check the
**APNS ENVIRONMENT** column on the Keys list reads `Sandbox & Production`.

**Remaining blockers**
1. **The three Auth accounts do not exist.** Firebase Auth holds exactly one
   user, `waseem.balloul@yahoo.com`, left over from the Google era. Nobody can
   sign in to the new build until `moayad@`, `waseem@` and `admin@sanayed.app`
   are created — and the tester bypass is gone, so there is no way back in.
2. Merge both branches and ship a build; sign in and tap Allow.
3. `GoogleService-Info.plist` is still not in the Xcode target (§4). Harmless
   for Auth/Firestore, but the first suspect if the app registers and no
   document appears in `device_tokens`.
4. Provisioning profiles were invalidated by enabling the push capability.
   Expect the first Codemagic build to fail on signing if it uses manual
   profiles.

**Housekeeping**
- Revoke Apple key `F43F229PFL` (Sandbox-only, unused). Apple allows two keys
  per account and both slots are currently taken.
- Delete the orphaned Firebase iOS app `com.sanayed.analyzer` — it appears in
  the Cloud Messaging app picker next to the real one and uploading a key to it
  would succeed and deliver nothing.
- The Firebase CLI needed `firebase login --reauth`; a stale token surfaced as
  `HTTP 401` on the rules-compile call, not as an auth error.

---

### 3.5 Data Export

**Purpose.** Get the currently visible data out as a file or an email.

**UI components**
- `widgets/export_menu.dart` — single `PopupMenuButton`, recipient dialog,
  busy/success/error snackbars
- Alerts tab → Excel + Email (`_AlertsExportMenu`)
- Dashboard → PDF + Email (`_DashboardExportMenu`)

**Business logic** — `services/export_service.dart`:
- `buildAlertsWorkbook` — `.xlsx` with localised headers and enum labels
- `captureBoundary` — rasterises the dashboard `RepaintBoundary` after a settle
  delay and a `debugNeedsPaint` re-check
- `buildDashboardPdf` — A4, RTL-aware, embeds the capture with `BoxFit.contain`
- `loadPdfFonts` — Noto Sans Arabic; the built-in PDF fonts render Arabic as
  empty boxes
- `sharePdf` (via `printing`) / `shareFile` (via `share_plus`, correct mime)
- `emailFile` — POSTs `{to, filename, mimeType, contentBase64}`

**Critical property:** exports read **only in-memory state**. No Firestore call
is issued by any export path, so the file always matches what is on screen.

**Chart fidelity:** capturing the live widget tree means charts can never be
half-painted or empty in the PDF — the usual failure mode of DOM/canvas
screenshotting.

**⚠️ Email endpoint is not configured.** `emailEndpoint` defaults to `''`; the
menu item shows "not configured" instead of failing silently. Set with
`--dart-define=EMAIL_ENDPOINT=…`. **No backend exists yet.**

---

### 3.6 Localisation & RTL

**Purpose.** Arabic-first UI that also handles English content correctly.

- ARB files `lib/l10n/app_ar.arb` (primary) and `app_en.arb`; `labels.dart` maps
  every enum to a localised label — **no raw wire key is ever displayed**
- Arabic is the default locale; toggle in Settings
- `AutoDirectionText` detects direction from the first strongly-directional
  character, so an English message inside the RTL layout renders LTR with its
  punctuation in the right place
- `PhoneText` forces LTR so `+963…` never breaks
- Card chrome stays RTL; only content strings are direction-detected

**⚠️ Do not edit `.arb` files with PowerShell `Get-Content`/`Set-Content`.**
PowerShell 5.1 reads UTF-8 as ANSI and rewrites it double-encoded, corrupting
every Arabic character. Use the editor, or .NET `File.ReadAllText`/`WriteAllText`
with explicit UTF-8.

---

## 4. Current Progress

### ✅ Fully implemented and verified

- Username + password sign-in (Firebase email/password over a synthetic
  `@sanayed.app` domain), gated by the `allowed_users` allowlist
- Alerts queue: filters, skeletons, empty states, pull-to-refresh, detail view
- Status lifecycle: confirmations, revert, `completion_date`, optimistic writes
- Dashboard: 2nd Firestore subscription, escalation rate, 9 visualisations,
  independent filters
- In-app alert chime with first-snapshot suppression + settings toggle
- Excel export (alerts) and PDF export (dashboard, with real chart capture)
- Arabic/English localisation, RTL, per-string direction detection
- Firestore rules: allowlist read-public/write-admin, alerts read + narrow
  status/completion write, everything else closed — **deployed and probe-verified**
- Android release APK builds and installs (`com.sanayed.analyzer`)
- iOS release build succeeds on Codemagic and **uploads to App Store Connect**
- TestFlight internal group "Beta Testers" with 2 testers invited
- App icon generated for all platforms from the Sanayed artwork
- `flutter analyze` clean · **36/36 tests pass** · web + APK + IPA all build

### 🚧 In progress / partially done

- **Build 2 not yet distributed.** Commit `942fe45` (new icon, build number 2,
  encryption declaration) is pushed, but Codemagic builds appear to be started
  **manually** — verify a build ran for that commit.
- **`GoogleService-Info.plist` is not referenced by the Xcode target.** It sits
  in `ios/Runner/` and is committed, but is not in the build phase. Firebase
  still initialises from `firebase_options.dart`, so nothing is broken. Fix by
  dragging it into the Runner group next time Xcode is open.
- **n8n workflows in `n8n/` emit an older document shape** than the app now
  reads. They are reference material, not the live workflow.

### ⏭ Immediate next tasks

1. **Provision the password accounts** — before this build ships to anyone:
   enable the Email/Password provider, create each staff account as
   `<username>@sanayed.app` in Firebase Auth, and add a matching
   `allowed_users` row whose `email` field is that same synthetic address.
   Existing allowlist rows hold real work emails and will **not** match.
2. Confirm build 2 reached TestFlight; install and verify the new icon.
3. **Lock down `/alerts` reads.** Currently `allow read: if true` — the data is
   readable by anyone with the web API key. Change to require an authenticated,
   allowlisted user now that sign-in works.
4. **Tighten `allowed_users` read.** `allow read: if true` was justified by the
   magic-link flow checking the allowlist *before* authenticating. That is no
   longer true — the check now runs post-auth — so it can become
   `if request.auth != null`. **Deploy only after this build is live**, or the
   currently-installed magic-link build loses its pre-auth allowlist read.
5. Decide on the email export backend, or drop the feature from the UI.
6. Align the n8n workflow JSON with the current Firestore contract.
7. Optional: background push notifications (needs FCM + n8n changes).

---

## 5. Technical Decisions & Constraints

> Fixed bugs and deliberate choices. **Do not regress these.**

### Platform identifiers — intentionally different per platform

| Platform | Identifier | Note |
|---|---|---|
| Android | `com.sanayed.analyzer` | Changing it makes a *different app*; testers could not update |
| iOS | `com.sanayed.tulipAlerts` | **Registered with Apple — cannot be renamed or deleted** |
| Firebase iOS | `com.sanayed.tulipAlerts` | Must match the Xcode value exactly |

These namespaces are independent; Firebase supports different IDs per platform.
The mismatch is **correct**, not a bug. An orphaned Firebase iOS app for
`com.sanayed.analyzer` may still exist and can be deleted.

### iOS build configuration

- **`IPHONEOS_DEPLOYMENT_TARGET = 15.0`** in all 3 places in `project.pbxproj`,
  and `platform :ios, '15.0'` in the Podfile. Firebase's iOS SDKs require 15.0;
  anything lower fails `pod install`.
- **`ios/Podfile` is committed deliberately.** Flutter does not ship one in the
  template — CocoaPods generates it on first `pod install`, *without* the
  platform line, which is what caused the original remote build failure.
- The Podfile's `post_install` hook forces `IPHONEOS_DEPLOYMENT_TARGET = 15.0`
  on **every pod**. Without it, individual pods keep their own minimum and the
  build fails with "compiling for iOS X, but module was built for iOS 15".
- ~~No `iOSBundleId` in `ActionCodeSettings`~~ — moot since magic links were
  removed. Kept as history: passing an unregistered bundle ID made Firebase
  reject the whole `sendSignInLinkToEmail` call, which caused "could not send
  the sign-in link" on the first Android build. It will matter again if any
  email-based flow is ever reintroduced.
- `ITSAppUsesNonExemptEncryption = false` in `Info.plist` — answers App Store
  Connect's export-compliance question automatically on every upload.
- `CFBundleURLTypes` contains the `REVERSED_CLIENT_ID`. It was **required** for
  iOS Google sign-in; now that Google sign-in is gone from the app it is unused
  but harmless, and is left in place so the flow can be restored without
  another iOS config round-trip. (Without it, the browser completes auth and
  nothing catches the redirect, so sign-in silently never finishes.)

### App icons

- The 1024px marketing icon **must be 24-bit RGB with no alpha channel** —
  App Store Connect rejects alpha outright. Generation strips it explicitly.
- Source artwork is a mockup with a blurred backdrop; it must be **cropped to
  the icon tile** before resizing (crop origin `209,209`, size `1630`).

### Firestore

- **Composite index required:** `needs_attention` ASC + `message_at` DESC, in
  `firestore.indexes.json` and deployed.
- **Rules permit exactly one client write shape:** `hasOnly(['status',
  'completion_date'])`, with `done` requiring a timestamp and any other status
  requiring the field absent/null.
- Documents produced before the schema cutover lack `message_at` and are
  therefore invisible to the alerts query. Expected, not a bug.
- **`created_at` must never be shown** to the user; `message_at` (via
  `Alert.timeAt`) drives all displayed times.

### Data-contract invariants

- Enum wire values are lowercase `snake_case`. Unknown values fall back to
  `unknown`/`other` **and are logged** via `dart:developer` (name `alerts`) so
  model drift is visible rather than silently degrading.
- `priority`: `urgent` | `high` | `medium` | `low`
- `department`: `sales` | `operations` | `delivery` | `finance` | `support` |
  `management`
- Sender resolution order: `sender_name` → `display_name` → `sender_phone` →
  localised "unknown".
- `needs_attention: false` correlates exactly with `priority: low` in live data —
  those are the messages that never become alerts.

### Tooling

- Flutter SDK is **not on PATH**; it lives at `C:\dev\flutter\bin`.
- `flutter create` regenerates `test/widget_test.dart` referencing a
  non-existent `MyApp`, which breaks `flutter analyze`. Delete it after any
  `flutter create` run.
- `intl` is pinned by `flutter_localizations`; keep it as `any`.
