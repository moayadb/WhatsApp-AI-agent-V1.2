# PROJECT_KNOWLEDGE_BASE.md — Sanayed (سانايد)

> **Purpose.** The single technical knowledge document for the "Software
> Architecture Advisor" Claude Project. Upload this **first**, then the source
> files listed in §10.
>
> This is the sole technical reference — it supersedes and replaces the earlier
> `SOFTWARE_ADVISOR_CONTEXT.md`, which has been removed to avoid two competing
> sources of truth.
>
> Verified against the codebase at commit `942fe45`.

---

## 0. Orientation — read before anything else

**Sanayed is a single Flutter codebase** targeting iOS, Android and Web. There
is **no HTML/JavaScript frontend**, no `package.json`, no DOM, no `<canvas>`.
`web/index.html` is only Flutter's bootstrap. All charts are **`fl_chart`
widgets**.

### ⚠️ Never recommend these — they have nothing to attach to

| Do not suggest | Because | Use instead |
|---|---|---|
| **Chart.js**, D3, Recharts | No canvas, no DOM | `fl_chart` widgets |
| **SheetJS (xlsx)** | No JS runtime | `excel` package |
| **html2pdf.js**, jsPDF | Nothing to rasterise | `pdf` + `printing` + `RepaintBoundary` capture |
| **Print-specific CSS**, `@media print` | No stylesheets | Exclude widgets from the capture boundary |
| React / Vue / any JS framework | Not a web app in that sense | Flutter widgets |

If the user mentions any of these, correct them once, plainly, and proceed with
the Flutter reality.

**The app is read-mostly.** An external n8n workflow writes alert documents;
the app reads them and writes exactly one field pair (`status` +
`completion_date`). It has **no capability to send messages** — verified by
codebase search, zero matches.

---

## 1. Tech Stack — exact versions

| Layer | Technology | Version |
|---|---|---|
| Framework | Flutter / Dart | 3.44.x / 3.12.x |
| State management | **`provider`** (ChangeNotifier) | ^6.1.5+1 |
| Database | `cloud_firestore` | ^6.7.1 |
| Auth | `firebase_auth` | ^6.5.6 |
| Core | `firebase_core` | ^4.12.1 |
| Charts | `fl_chart` | ^1.2.0 |
| Relative time | `timeago` | ^3.7.1 |
| Local storage | `shared_preferences` | ^2.5.5 |
| Audio | `audioplayers` | ^6.8.1 |
| Spreadsheet export | `excel` | ^4.0.6 |
| PDF | `pdf` / `printing` | ^3.12.0 / ^5.14.3 |
| File share | `share_plus` | ^13.3.0 |
| HTTP | `http` | ^1.6.0 |
| Localisation | `flutter_localizations` + `intl` | SDK + `any` |
| CI/CD | Codemagic (macOS runners) | — |
| Ingestion | n8n (external to this repo) | — |

**State management is `provider` throughout.** Do NOT propose Riverpod, BLoC,
GetX or MobX unless the user explicitly asks to migrate. Consistency with the
existing pattern outranks preference.

**`intl` must stay `any`** — `flutter_localizations` from the SDK pins the real
version; specifying one causes resolution failure.

---

## 2. System Architecture

```
Customer ──WhatsApp──► n8n workflow (external repo)
                            │  • routes by type: text / image / audio
                            │  • transcribes audio, describes images (AI)
                            │  • classifies: priority, department, category
                            │  • writes via Google service account
                            ▼
                   Firestore collection `alerts`
                   (ONE document per ANALYSED MESSAGE,
                    not per alert)
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
      AlertsProvider              DashboardProvider
   needs_attention == true        no filter — ALL docs
   orderBy message_at desc        orderBy created_at desc
   limit 200                      limit 500
              └─────────────┬─────────────┘
                            ▼
              Flutter UI — 3 tabs in one shell
```

**Why two subscriptions.** The alerts list is an action queue and must show
only flagged messages. The dashboard must see *every* analysed message —
otherwise the escalation rate (alerts ÷ total analysed) is structurally
impossible to compute. Both are created above the navigation shell in
`main.dart` and started once when `MainShell` mounts. **Never open a listener
inside a screen** — it multiplies cost and lets tabs disagree.

---

## 3. Architecture Pattern & Folder Structure

### Pattern: layered, provider-mediated

```
   UI (screens/, widgets/)
        │  reads state, calls methods
        ▼
   State (providers/)          ← ChangeNotifier, owns streams & filters
        │  calls
        ▼
   Services (services/)        ← the ONLY code touching the outside world
        │  produces
        ▼
   Models (models/)            ← framework-free, unit-testable
```

**Rules this pattern enforces:**
- Screens never touch Firestore. All access flows through `AlertsService`.
- Models import **no Flutter**, so they are testable without a widget binding.
  Priority *colours* therefore live in `theme/`, not on the enum.
- Enum wire values are never displayed; `l10n/labels.dart` maps every enum to a
  localised label.

### Folder structure

```
lib/
  main.dart                  Bootstrap, MultiProvider, auth gate (_Root)
  firebase_options.dart      Generated — web + android + ios blocks

  models/                    NO Flutter imports
    alert.dart               Alert + 6 enums, defensive fromFirestore (~317 ln)
    app_user.dart            AppUser, UserRole → default department

  services/                  Outside-world boundary
    alerts_service.dart      THE only Firestore access point (~61 ln)
    auth_service.dart        AuthService interface + FirebaseAuthService (~250 ln)
    export_service.dart      Excel / PDF / capture / share / email POST (~213 ln)
    notification_sound.dart  In-app chime singleton (~51 ln)

  providers/                 State + orchestration
    alerts_provider.dart     Alert stream, filters, optimistic writes (~220 ln)
    dashboard_provider.dart  Analytics stream, DashboardMetrics (~245 ln)
    auth_provider.dart       Login phase machine, tester bypass (~187 ln)
    settings_provider.dart   Theme + locale (~30 ln)

  screens/
    login_screen.dart        3-phase magic-link UI + Google (~242 ln)
    main_shell.dart          One Scaffold + AppBar + NavigationBar (~125 ln)
    alerts_tab.dart          List, filter chips, Excel export (~231 ln)
    alert_detail_screen.dart Detail, confirmations, revert (~457 ln)
    dashboard_tab.dart       All charts + PDF export (~1114 ln — largest file)
    settings_tab.dart        Account, theme, language, sound, sign out (~131 ln)

  widgets/
    alert_card.dart          List card
    badges.dart              PriorityBadge, CategoryBadge, StatusBadge, PhoneText
    auto_direction_text.dart Per-string RTL/LTR detection
    connection_pill.dart     Inferred WhatsApp-activity indicator
    export_menu.dart         Shared export PopupMenuButton
    states.dart              EmptyState, SkeletonList

  theme/app_theme.dart       Colour system, light/dark, priority colour map
  l10n/                      app_ar.arb, app_en.arb, labels.dart, generated/

test/                        alert_model_test.dart, dashboard_metrics_test.dart
                             (31 tests, all passing; NO widget tests)
n8n/                         Workflow JSON + docs — reference only, NOT app code
ios/ android/ web/           Platform shells
```

---

## 4. State Management — `provider` / ChangeNotifier

Used **consistently**. No Riverpod, BLoC, GetX or MobX anywhere. Do not propose
migrating without an explicit request.

### Provider registration (`main.dart`)

```dart
MultiProvider(providers: [
  ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
  ChangeNotifierProvider(create: (_) => AuthProvider(FirebaseAuthService())
      ..restore(initialLink: initialLink)),
  ChangeNotifierProvider(create: (_) => AlertsProvider(_alertsService)),
  ChangeNotifierProvider(create: (_) => DashboardProvider(_alertsService)),
])
```

Both alert providers share **one** `AlertsService` instance — same collection,
two differently-scoped queries.

### The four providers

| Provider | Owns | Key API |
|---|---|---|
| `AlertsProvider` | Alert stream, client-side filters, optimistic writes, chime trigger | `filteredAlerts`, `effectiveStatus()`, `setStatus()`, `whatsAppStatus` |
| `DashboardProvider` | Analytics stream, own independent filters | `metrics` → `DashboardMetrics`, `setRange()`, `setDepartment()` |
| `AuthProvider` | Login phase machine (`enterEmail` / `linkSent` / `confirmEmail`) | `requestMagicLink()`, `signInWithGoogle()`, `errorCode` |
| `SettingsProvider` | Theme mode + locale, persisted | `setDark()`, `setLocale()` |

### How the UI connects to logic

**Alerts tab** → `context.watch<AlertsProvider>()` → renders `filteredAlerts`.
Filtering is **client-side in Dart** over the already-loaded list, so filter
changes are instant and require no extra composite indexes.

**Dashboard tab** → `context.watch<DashboardProvider>()` → `provider.metrics`
recomputes `DashboardMetrics.from(scoped, dayCount)` in a single pass over the
in-memory list. **Zero additional Firestore reads for any chart.**

**Detail screen** → reads the live alert from the provider by id, so a status
change arriving from the server updates the open screen.

**Optimistic writes.** `setStatus()` applies a local override immediately, calls
Firestore, and rolls back on failure. `effectiveStatus(alert)` returns the
override if a write is in flight. Server-confirmed states supersede overrides
on the next snapshot.

**Chime trigger.** Inside `AlertsProvider`'s stream listener: document IDs from
the *first* snapshot are recorded silently; only IDs unseen afterwards fire
`NotificationSound.playNewAlert()`. Prevents a burst on cold start.

---

## 5. Firebase / Firestore

### 4.1 Collection `alerts` — 31 fields

One document per **analysed message**. Documents with
`needs_attention == false` (which correlates exactly with `priority: low` in
live data) are counted by the dashboard but excluded from the queue.

**AI classification**
| Field | Type | Values / notes |
|---|---|---|
| `needs_attention` | bool | Queue filter |
| `priority` | string | `urgent` \| `high` \| `medium` \| `low` |
| `department` | string | `sales` \| `operations` \| `delivery` \| `finance` \| `support` \| `management` |
| `category` | string | `customer_complaint`, `customer_dissatisfaction`, `refund_request`, `delivery_problem`, `payment_issue`, `wrong_or_damaged_order`, `quality_issue`, `legal_threat`, `vip_issue`, `general_inquiry` |
| `summary` | string | One Arabic line — **card/detail TITLE only, never the bubble** |
| `reason` | string | Why it was flagged |
| `action` | string | Recommended action |

**Contact**
| Field | Type | Notes |
|---|---|---|
| `sender_name` | string | May be empty |
| `display_name` | string | Guaranteed non-empty |
| `first_name` / `last_name` | string | `last_name` often empty |
| `sender_phone` | string | E.164 |
| `country` | string | ISO-2, derived from phone prefix |
| `contact_id` | string | Falls back to phone |

**Conversation**
| Field | Type | Notes |
|---|---|---|
| `conversation_id` | string | Stable per conversation |
| `account_id`, `wa_message_id` | string | |
| `channel`, `source` | string | Always `whatsapp` |
| `conversation_status`, `assignee` | string | **Always empty — no UI renders them** |

**Message**
| Field | Type | Notes |
|---|---|---|
| `message_type` | string | `text` \| `image` \| `audio` |
| `message_content` | string | Customer's own words; caption for media |
| `media_analysis` | string | AI transcript (audio) / description (image) |
| `display_text` | string | Pre-resolved bubble text |
| `display_source` | string | `customer_message` \| `audio_transcript` \| `image_description` |
| `direction` | string | `incoming` \| `outgoing` |

**Lifecycle**
| Field | Type | Notes |
|---|---|---|
| `message_at` | Timestamp | **The user-facing time** |
| `created_at` | Timestamp | Write time — **never displayed** |
| `status` | string | `new` \| `done` \| `ignored` — **app-written** |
| `completion_date` | Timestamp \| null | **app-written** |

### 4.2 Collection `allowed_users` — the sign-in allowlist

**Document ID is the lowercase email.** This is deliberate: it lets security
rules enforce membership cheaply via
`exists(/allowed_users/$(request.auth.token.email))` without running a query.

```json
{ "email": "person@example.com", "role": "owner", "added_at": <Timestamp> }
```

`role` ∈ `owner` | `sales` | `purchasing`. It seeds the **default department
filter** on both tabs. It is a convenience default, **not a security boundary**
— any signed-in user can widen it.

### 4.3 Collection `admins/{uid}`

Existence-only records. Referenced by rules to authorise allowlist writes.
Never client-writable.

### 4.4 Security rules — current state

```
allowed_users  read:   PUBLIC   (the gatekeeper runs pre-authentication)
               write:  admins only (exists(/admins/$(request.auth.uid)))

admins/{uid}   read:   admins only
               write:  never

alerts         read:   PUBLIC  ⚠️ SEE WARNING BELOW
               update: ONLY affectedKeys().hasOnly(['status','completion_date'])
                       AND status ∈ ['new','done','ignored']
                       AND (status == 'done' ⇒ completion_date is timestamp)
                       AND (status != 'done' ⇒ completion_date absent or null)
               create: denied
               delete: denied

{document=**}  read/write: denied
```

> ⚠️ **`allow read: if true` on `/alerts` is a production blocker.** Customer
> names, phone numbers and message contents are readable by anyone holding the
> web API key — which ships inside the JS bundle. Left open deliberately so
> testing could proceed before sign-in was proven. Must become
> `request.auth != null`, ideally plus allowlist membership.

**Why service-account writes still work:** n8n authenticates with a Google
service account, which goes through **IAM, not security rules** — bypassing
them entirely. That is why rules can deny all client creates while ingestion
continues.

**Composite index (deployed):** `needs_attention` ASC + `message_at` DESC.
Required because the query filters on one field and orders by another.

### 4.5 Firebase Auth

Two providers, **both gated by the same allowlist**:

1. **Email magic link** — `sendSignInLinkToEmail`. Allowlist is checked *before*
   the link is sent, so an unauthorised address never receives one. The email
   is stored in `shared_preferences` and required back to complete sign-in.
2. **Google** — `signInWithProvider` (browser flow). After Google authenticates,
   the email is checked against `allowed_users`; a non-listed account is signed
   straight back out.

**Google deliberately uses the browser flow, not the `google_sign_in` plugin** —
it needs no SHA-1 fingerprint registration and no `serverClientId`, so it works
on a fresh release APK with zero extra configuration.

---

## 6. n8n Webhook Structures & Data Flow

n8n lives **outside this repository**. The JSON files in `n8n/` are historical
reference and **emit an older document shape than the app now reads**. Treat
them as illustrative of the pattern, not as the live workflow.

### 5.1 Pipeline shape

```
WhatsApp webhook (POST, responds 200 immediately)
        │
   Normalize Message  (Code node — flattens the provider payload)
        │
   Route By Type  (Switch)
        ├── image → convertToFile → AI describe  ─┐
        ├── audio → convertToFile → AI transcribe ─┼→ Unified Message (Set)
        └── text  ─────────────────────────────────┘        │
                                                            ▼
                              AI Agent + Structured Output Parser
                              → { needs_attention, priority, department,
                                  category, summary, reason, action }
                                                            │
                                                    Build Alert (Code)
                                                            │
                                              Create Firestore Alert
                                              (HTTP Request, service account)
```

### 5.2 Node roles

| Node | Type | Responsibility |
|---|---|---|
| Webhook | `n8n-nodes-base.webhook` | Receives message; responds 200 at once so the provider never retries while AI runs |
| Normalize Message | Code | Flattens provider payload; drops own outbound messages, group chats, presence/status events |
| Route By Type | Switch | text / image / audio branches |
| To Binary | convertToFile | Base64 → binary for media |
| Analyze / Transcribe | LangChain OpenAI | Image description / audio transcript |
| Unified Message | Set | **Convergence point** — one stable node reference for downstream text, regardless of branch |
| AI Agent + Output Parser | LangChain | Structured classification |
| Build Alert | Code | Maps verdict → typed Firestore payload; clamps enums |
| IF | if | Gates whether a document is written |
| Create Firestore Alert | HTTP Request | POST to Firestore REST with a service account |

### 5.3 Integration rules the workflow MUST honour

1. **Timestamps must be written as Firestore `timestampValue`, not strings.**
   A string will not convert via `Timestamp.toDate()`; the alert then shows
   "unknown time" with no error anywhere. Silent and hard to diagnose.
2. **Enum values must be lowercase `snake_case`** and match the vocabularies in
   §5.1 exactly. Live data still contains drift from an earlier workflow
   version (`"Customer Complaint"`, `"N/A"`, `"room inquiry"`) which the app
   buckets as "other" **and logs**.
3. **Every analysed message should be written, not just alerts.** Documents
   with `needs_attention: false` are what make the escalation-rate metric
   possible.
4. **`message_at` must be present.** Firestore drops documents missing the
   `orderBy` field, so an alert without it is invisible to the queue. This is
   also why the dashboard orders by `created_at` instead — ordering the
   analytics query on `message_at` silently skewed every metric.
5. **Auth is a Google service account** with the `datastore` scope and the
   *Cloud Datastore User* role. Missing scope produces a `403` that looks like
   a rules problem but is not.

### 5.4 App → external (the only egress)

The email export POSTs `{to, filename, mimeType, contentBase64}` to a
configurable endpoint. `ExportService.emailEndpoint` defaults to `''`, so the
UI shows "not configured" rather than failing silently. **No backend exists.**

---

## 7. Model Parsing Contract

`models/alert.dart` is **defensive by design** — documents come from an external
workflow and any field may be missing, null, or the wrong type. Nothing throws.

**Unknown enum values fall back AND log** via `dart:developer` (logger name
`alerts`), so model drift is visible rather than silently degrading.

**Derived getters encapsulate the messy fallbacks** — use these, never the raw
fields:

| Getter | Resolution |
|---|---|
| `timeAt` | `message_at` ?? `created_at` |
| `displayText` | `display_text` → `media_analysis` → `message_content` |
| `displaySource` | parsed value, else derived from `message_type` |
| `resolvedSender` | `sender_name` → `display_name` → `sender_phone` → empty |
| `hasDistinctCaption` | media message whose caption differs from the bubble |
| `handlingTime` | `completion_date` − `timeAt` |
| `initials` | first letters of up to two words of `resolvedSender` |

**UI rule that is easy to regress:** the message bubble renders `displayText`,
**never `summary`**. `summary` is the card/detail title only. A source badge is
always shown so an AI transcript is never mistaken for the customer's literal
words.

---

## 8. Platform Constraints — DO NOT REGRESS

### Bundle identifiers differ per platform — this is correct

| Platform | Identifier | Status |
|---|---|---|
| iOS `PRODUCT_BUNDLE_IDENTIFIER` | **`com.sanayed.tulipAlerts`** | Registered with Apple — **immutable** |
| Android `applicationId` | `com.sanayed.analyzer` | Changing it breaks tester updates |
| Firebase iOS app | `com.sanayed.tulipAlerts` | Must match Xcode exactly |

The iOS value appears **twice** in `project.pbxproj` (Runner and
Runner.RunnerTests) and again in `GoogleService-Info.plist`.

Apple bundle IDs **cannot be renamed or deleted** once registered. iOS and
Android namespaces are independent and Firebase supports different IDs per
platform, so the apparent inconsistency is deliberate and correct.

### iOS build

- `IPHONEOS_DEPLOYMENT_TARGET = 15.0` in all three places in `project.pbxproj`
  + `platform :ios, '15.0'` in the Podfile. Firebase requires 15.0.
- **`ios/Podfile` is committed deliberately** — Flutter ships none, and
  CocoaPods generates one *without* the platform line, which caused the
  original remote build failure.
- Podfile `post_install` forces 15.0 onto **every pod**; without it the build
  fails with *"compiling for iOS X, but module was built for iOS 15"*.
- **No `iOSBundleId` in `ActionCodeSettings`** — an unregistered bundle ID makes
  Firebase reject the entire `sendSignInLinkToEmail` call. This caused the
  "could not send the sign-in link" failure.
- **`CFBundleURLTypes` must contain the `REVERSED_CLIENT_ID`** — required for
  iOS Google sign-in, or the redirect is never caught and sign-in silently
  never completes.
- `ITSAppUsesNonExemptEncryption = false` auto-answers export compliance.

### App icons
The 1024px marketing icon **must be 24-bit RGB with no alpha channel** — App
Store Connect rejects alpha outright.

### Release
- Apple rejects **duplicate build numbers**; `pubspec.yaml` is at `1.0.0+2`.
- **Release mode is mandatory** — Flutter debug builds ship a JIT Dart VM and
  are rejected.
- Codemagic builds appear to be **started manually**, not push-triggered.

### Tooling gotchas
- Flutter is **not on PATH**; it lives at `C:\dev\flutter\bin`.
- `flutter create` regenerates `test/widget_test.dart` referencing a
  non-existent `MyApp`, breaking `flutter analyze`. Delete it afterwards.
- **Never edit `.arb` files with PowerShell `Get-Content`/`Set-Content`** —
  PowerShell 5.1 reads UTF-8 as ANSI and rewrites it double-encoded, corrupting
  every Arabic character. **This has already happened once.**
- `intl` must stay `any` — pinning it breaks resolution against the SDK.
- **`printing` does not support Swift Package Manager.** A build warning today,
  an error in a future Flutter release. Watch for it if iOS builds start
  failing after a Flutter upgrade.

---

## 9. Known Issues & Technical Debt

### 🔴 Blocking production

1. **`/alerts` allows unauthenticated reads.** Rules say `allow read: if true`.
   Customer names, phone numbers and message contents are readable by anyone
   holding the web API key, which ships in the JS bundle. Left open
   deliberately so testing could proceed before sign-in was proven. **Must
   become `request.auth != null`, ideally plus allowlist membership.**
2. **Tester bypass in `lib/providers/auth_provider.dart`.** Typing a hardcoded
   code into the email field grants owner-level access with **no Firebase call
   at all**. Default value **`sanayed2026`**, overridable at build time via
   `--dart-define=BYPASS_CODE=…`. It sits behind a clearly marked comment
   block. **Must be removed before any real release** — delete the block, the
   check in `requestMagicLink`, and the `restore`/`signOut` handling.

### 🟡 Worth knowing

3. **No background/push notifications.** The chime fires only while the app is
   running. Real push needs FCM + notification channels + APNs + n8n changes.
4. **Email export has no backend.** `ExportService.emailEndpoint` is unset by
   design; the UI shows "not configured" rather than failing silently.
5. **n8n workflow JSONs in `n8n/` are outdated** relative to the current
   document contract. Historical reference only.
6. **`GoogleService-Info.plist` is not referenced by the Xcode target.** It is
   committed and present, but not in the build phase. Firebase still
   initialises from `firebase_options.dart`, so nothing is broken. Fix by
   dragging it into the Runner group in Xcode.
7. **`DashboardStats` (in `alerts_provider.dart`) is legacy**, superseded by
   `DashboardMetrics` in `dashboard_provider.dart`. Both exist; only the latter
   drives the current dashboard.
8. **Pre-cutover documents lack `message_at`** and are therefore invisible to
   the alerts query — Firestore drops documents missing the `orderBy` field.
   Expected, not a bug. It is also why the dashboard orders by `created_at`.
9. **No widget tests.** The 31 existing tests cover model parsing, enum
   fallbacks, sender resolution, message-bubble precedence, direction detection
   and dashboard aggregation — the logic most likely to break silently.

---

## 10. Files to Upload Alongside This Document

Upload in priority order. **Tier 1 is the minimum** for a competent advisor;
Tier 2 substantially improves specificity.

### Tier 1 — essential (9 files, all small)

| File | Why |
|---|---|
| `PROJECT_KNOWLEDGE_BASE.md` | This document — upload first |
| `pubspec.yaml` | Ground truth for dependencies and versions |
| `lib/models/alert.dart` | The entire data contract + defensive parsing |
| `lib/services/alerts_service.dart` | Every Firestore query and the single write |
| `lib/providers/alerts_provider.dart` | Core state pattern, optimistic writes, chime |
| `lib/providers/dashboard_provider.dart` | Analytics pattern + `DashboardMetrics` |
| `lib/services/auth_service.dart` | Auth abstraction, allowlist, ActionCodeSettings |
| `firestore.rules` | Security model |
| `lib/main.dart` | Provider topology and wiring |

### Tier 2 — strongly recommended (6 files)

| File | Why |
|---|---|
| `lib/models/app_user.dart` | Roles → default department (tiny) |
| `lib/providers/auth_provider.dart` | Login phase machine + tester bypass |
| `lib/services/export_service.dart` | Excel/PDF/capture patterns |
| `lib/screens/alerts_tab.dart` | Representative screen + filter UI |
| `ios/Podfile` | The deployment-target constraint in context |
| `firestore.indexes.json` | Composite index (tiny) |

### Tier 3 — optional

| File | Why |
|---|---|
| `PROJECT_STATE.md` | Feature-by-feature progress; overlaps §11 |
| `lib/theme/app_theme.dart` | Only for design/theming questions |
| `lib/l10n/app_en.arb` | Only for copy/localisation questions |
| `n8n/*.json` | Only for workflow questions — **outdated shape** |

### Do NOT upload

| File | Reason |
|---|---|
| `lib/screens/dashboard_tab.dart` | ~1114 lines, mostly chart boilerplate — burns budget. Paste the relevant excerpt when asking about a specific chart |
| `lib/l10n/generated/**` | Generated; regenerated by `flutter gen-l10n` |
| `pubspec.lock` | Noise |
| `build/`, `.dart_tool/` | Artifacts |
| `ios/Runner.xcodeproj/project.pbxproj` | Huge and machine-generated. The constraints that matter are in §8 |

---

## 11. Current Status Snapshot

> ⚠️ **This section ages fastest.** Treat it as a starting point, not current
> truth — confirm against the repository before relying on it.

**Working and verified:** magic-link + Google auth with allowlist · alerts
queue with filters · status lifecycle with confirmations and revert ·
dashboard with 9 visualisations and escalation rate · in-app chime · Excel and
PDF export · Arabic/English RTL · deployed security rules · Android APK · iOS
IPA building on Codemagic and uploading to TestFlight.

**Quality baseline — preserve this:** `flutter analyze` clean · **31/31 tests
pass** · web, APK and IPA all build. Every implementation prompt must instruct
the coding agent to keep it.

**Blocking production:** see §9 — unauthenticated `/alerts` reads, and the
tester bypass.

---

## 12. Quick Reference

| Question | Answer |
|---|---|
| State management? | `provider` / `ChangeNotifier` — consistently |
| How many Firestore listeners? | **Exactly two**, both above the shell |
| Where does Firestore get touched? | `services/alerts_service.dart` only |
| What does the app write? | `status` + `completion_date`. Nothing else |
| Can it send messages to customers? | **No** — zero such capability exists, by design |
| iOS bundle ID? | `com.sanayed.tulipAlerts` — **immutable, registered with Apple** |
| Android applicationId? | `com.sanayed.analyzer` — **do not change** |
| iOS minimum version? | 15.0 (Firebase requirement) |
| Is there a JS/HTML frontend? | **No.** Flutter only; charts are `fl_chart` |
| Which timestamp is displayed? | `message_at`; `created_at` is never shown |
| Primary language? | Arabic, RTL |
| Test count? | 31, all passing; no widget tests |
| Current version? | `1.0.0+2` |
