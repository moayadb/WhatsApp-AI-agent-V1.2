# Push notifications — the n8n send side

> The app **receives** pushes (`lib/services/push_service.dart`). Nothing in the
> app sends one. This is the missing half: four nodes on the end of the existing
> alert workflow.
>
> n8n never talks to the app. n8n tells FCM, FCM tells APNs, APNs wakes the
> phone. The app's only job is to have registered a token.

**Import `sanayed-workflow-with-push.json`** — it is the complete production
workflow with the push branch already wired in. `push-nodes.json` is the older
standalone snippet, kept only for reference; prefer the full file.

**Duplicate your current workflow before importing**, so a bad import is one
click to undo.

```
… → AI Agent → Build Firestore Body → HTTP Request1 (write alert)
                                          │
                                          ▼
                                   Needs attention?
                                          │ true
                                          ▼
                                  Get Device Tokens
                                          │
                                          ▼
                                  Build FCM Payloads   (one item per device)
                                          │
                                          ▼
                                     Send to FCM ──► APNs ──► phone
```

---

## 1. The one credential you must create

**`Send to FCM` has no credential attached. Everything else is already wired.**

Your Firestore credential (`Google Firebase Cloud Firestore account 2`) is an
**OAuth2** credential carrying the `datastore` scope. It writes alerts and reads
`device_tokens` fine — but FCM will reject it with **403 `PERMISSION_DENIED`**,
because sending requires a different scope.

Create a **Google Service Account** credential in n8n:

1. Google Cloud Console → IAM & Admin → Service Accounts, on project
   `whatsapp-ai-agent-waseem`. The existing `firebase-adminsdk-…` account is
   fine — it already has the Firebase Admin SDK role, which covers FCM.
2. Keys → Add Key → Create new key → **JSON** → download.
3. In n8n: Credentials → New → **Google Service Account API**.
   - **Service Account Email** ← `client_email` from the JSON
   - **Private Key** ← `private_key` from the JSON, including the
     `-----BEGIN PRIVATE KEY-----` and `-----END-----` lines
   - Enable **Set up for use in HTTP Request node**
   - **Scope**: `https://www.googleapis.com/auth/firebase.messaging`
4. Open the `Send to FCM` node and select that credential.

That JSON key is a credential — keep it in n8n and your password manager, and
nowhere else. Delete the downloaded file afterwards.

---

## 2. Why the branch hangs off `HTTP Request1`

It reads the Firestore **create response**, not the pre-write body. Two reasons:

- Only alerts that actually persisted notify anyone. A failed write sends nothing.
- The response carries the generated document id, so `alert_id` in the payload
  is real and a future app version can deep-link straight to the alert.

This is also why `Needs attention?` tests
`{{ $json.fields.needs_attention.booleanValue }}` and not `$json.needs_attention`
— everything downstream of `Build Firestore Body` is in Firestore REST shape.

---

## 3. What the notification says

> **تنبيه جديد**
> عاجلة · المبيعات

Priority and department, mapped to Arabic in `Build FCM Payloads`. Routine
traffic never fires a phone — `Needs attention?` drops everything with
`needs_attention: false`, which is roughly half of all analysed messages.

**Customer message text is deliberately absent.** A notification body renders on
a locked screen in front of whoever is in the room, and these are complaints and
refund demands.

---

## 4. Two deliberate settings

**`Send to FCM` → Options → Response → Never Error is ON.** FCM v1 accepts one
token per request, so that node runs once per device. Without this, a single
dead token aborts the run and every manager behind it silently gets nothing.

**`Build FCM Payloads` returns zero items when nobody has registered.** The
branch just ends. No error, no empty request.

---

## 5. Nothing arrives until all four are true

1. **APNs auth key uploaded** — Firebase Console → Project settings → Cloud
   Messaging → `tulip_alerts (ios)`. Upload to **both** the development and
   production rows. Without it FCM returns success and nothing is delivered.
2. **`feature/push-notifications` merged and shipped to TestFlight.** Devices on
   the current build have no token and appear nowhere.
3. **Someone signed in on the new build and tapped Allow.** Check the
   `device_tokens` collection has at least one document before debugging
   anything else.
4. **This workflow imported** and the FCM credential attached.

---

## 6. Troubleshooting

| Symptom | Cause |
|---|---|
| `403 PERMISSION_DENIED` | `Send to FCM` is using the Firestore OAuth2 credential, or the service account credential lacks the `firebase.messaging` scope. |
| `401 UNAUTHENTICATED` | Private key pasted without its BEGIN/END lines, or with the `\n` escapes not expanded. |
| `404 UNREGISTERED` | Dead token — app uninstalled. Harmless, see below. |
| `400 INVALID_ARGUMENT` | `token` came through empty. Check `device_tokens` documents actually have a `token` string field. |
| `Build FCM Payloads` returns 0 items | `device_tokens` is empty — nobody has signed in on a build that has push. This is step 3, not a bug. |
| **HTTP 200 but nothing on the phone** | Almost always the APNs environment. A TestFlight build is signed for **production** APNs; if the key sits only on the development row, Apple discards every send without an error. |
| Works from Xcode, never on TestFlight | Same cause. `RunnerRelease.entitlements` sets `aps-environment: production` for exactly this reason. |

### Stale tokens

Tokens die when an app is uninstalled. They accumulate harmlessly — FCM returns
`404 UNREGISTERED` — but every alert then wastes a request per dead device. When
that starts to matter, add a node after `Send to FCM` that deletes the
`device_tokens` document whenever the response contains `UNREGISTERED`.

Not worth building at three testers.
