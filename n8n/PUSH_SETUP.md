# Push notifications — the n8n send side

> The app **receives** pushes (`lib/services/push_service.dart`). Nothing in the
> app sends one. This document is the missing half: three nodes bolted onto the
> end of the existing alert workflow.
>
> n8n never talks to the app. It tells FCM, FCM tells APNs, APNs wakes the
> phone. The app's only job is to have registered a token.

```
WhatsApp ─► n8n ─┬─► write Firestore alert doc      (already exists)
                 │
                 └─► IF needs_attention ─► read device_tokens ─► build ─► POST FCM
                                                                            │
                                                          APNs ─► phone ◄───┘
```

---

## 1. Credential — reuse the one you already have

n8n already writes alert documents to Firestore with a **Google Service Account**
credential. Use that same credential; do not create a second one.

It needs the `https://www.googleapis.com/auth/firebase.messaging` scope. The
default `firebase-adminsdk-…` service account has it. If the POST comes back
**403 `PERMISSION_DENIED`**, that scope is missing — see Troubleshooting.

**Project ID:** `whatsapp-ai-agent-waseem`

---

## 2. The three nodes

Add these after whatever node writes the alert document. `push-nodes.json` in
this folder can be pasted straight onto the n8n canvas (select all → Ctrl+V).

### Node 1 — IF: "Needs attention?"

Only flagged messages notify. Roughly half of all analysed traffic is routine
and must not fire a phone.

| Field | Value |
|---|---|
| Condition | Boolean → is true |
| Value 1 | `{{ $json.needs_attention }}` |

### Node 2 — Google Cloud Firestore: "Get device tokens"

| Field | Value |
|---|---|
| Operation | Get All Documents |
| Project ID | `whatsapp-ai-agent-waseem` |
| Collection | `device_tokens` |
| Return All | on |

Reads every registered device. The service account bypasses security rules, so
the `allow read: if false` on that collection does not affect it.

### Node 3 — Code: "Build FCM payloads"

Emits **one item per device**. Maps the wire enums to Arabic here rather than in
the HTTP node, so the labels stay readable and in one place.

Set **Mode: Run Once for All Items**. Change `'Write Alert'` on the marked line
to the actual name of your Firestore-write node.

### Node 4 — HTTP Request: "Send to FCM"

| Field | Value |
|---|---|
| Method | `POST` |
| URL | `https://fcm.googleapis.com/v1/projects/whatsapp-ai-agent-waseem/messages:send` |
| Authentication | Predefined Credential Type → Google Service Account API |
| Send Body | on · JSON · Using JSON |
| JSON | `{{ JSON.stringify($json.payload) }}` |
| Options → Response → Never Error | **on** |

**Never Error matters.** FCM v1 sends to one token per request, so this node runs
once per device. Without it, one dead token aborts the whole run and the
managers behind it never get notified.

---

## 3. What the notification says

Priority and department only:

> **تنبيه جديد**
> عاجلة · المبيعات

**Customer message text is deliberately not in the payload.** A notification body
renders on a locked screen in full view of anyone nearby, and these are customer
complaints. `alert_id` rides along in `data` so a future version can deep-link
into the alert.

---

## 4. Before any of this delivers

1. **APNs auth key uploaded** to Firebase Console → Project settings → Cloud
   Messaging → `tulip_alerts (ios)`. Without it every send returns success and
   nothing arrives.
2. **`feature/push-notifications` merged and shipped** to TestFlight. Devices
   running the older build have no token and appear nowhere in `device_tokens`.
3. **Someone signed in on the new build** and tapped *Allow* on the iOS prompt.
   Check `device_tokens` has at least one document before debugging anything
   else — an empty collection means Node 2 returns nothing and Node 4 never runs.

---

## 5. Troubleshooting

| Symptom | Cause |
|---|---|
| `403 PERMISSION_DENIED` | Service account lacks the `firebase.messaging` scope. Grant it **Firebase Cloud Messaging API Admin** in Google Cloud → IAM. |
| `404 UNREGISTERED` | Dead token — app uninstalled or reinstalled. Harmless. See below. |
| `400 INVALID_ARGUMENT` | Malformed body. Usually `token` came through empty; check Node 3's field mapping against what your Firestore node actually returns. |
| HTTP 200, nothing on the phone | Almost always the APNs environment. A TestFlight build is signed for **production** APNs; if the key is only on the development row in Firebase, Apple silently discards it. Upload the key to **both** rows. |
| Works in Xcode, never on TestFlight | Same cause. `RunnerRelease.entitlements` sets `aps-environment: production` for exactly this reason. |

### Stale tokens

Tokens die when an app is uninstalled. They accumulate harmlessly — FCM just
returns `404 UNREGISTERED` — but the collection grows and every alert wastes a
request per dead device. When it starts to matter, add a node after Node 4 that
deletes the `device_tokens` document whenever the response is `UNREGISTERED`.

Not worth building yet at three testers.
