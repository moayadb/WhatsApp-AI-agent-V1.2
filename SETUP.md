# Tulip Alerts — connecting the app to the n8n workflow

Two systems meet at one Firestore collection:

```
WhatsApp → n8n (service account, WRITES) → alerts → Flutter app (web API key, READS)
```

They authenticate in completely different ways, which is the part worth
understanding before clicking through consoles:

| | n8n → Firestore | Flutter app → Firestore |
|---|---|---|
| Credential | Google **service account** | Web API key in `firebase_options.dart` |
| Permission model | IAM role (`Cloud Datastore User`) | **Security rules** |
| Security rules apply? | **No — bypassed** | **Yes** |

That asymmetry is why `firestore.rules` can say `allow write: if false` without
breaking n8n: the service account never passes through rules at all.

---

## Part 1 — Make the app compatible

### 1.1 Deploy the security rules

A new Firestore database denies everything by default, so the app currently
shows its red error card with `permission-denied`. Deploy the rules:

```bash
firebase deploy --only firestore:rules --project whatsapp-ai-agent-waseem
```

`firestore.rules` grants read on `/alerts`, denies client writes, and closes
everything else.

> ⚠️ **Read the PII note in `firestore.rules` before deploying.** It currently
> ships `allow read: if true`, which makes customer names, phone numbers and
> messages readable by anyone who has the web API key — and that key is visible
> in the JS bundle of any deployed build. It is fine for local development.
> Before deploying the app anywhere public, switch to the
> `allow read: if request.auth != null` line and add Firebase Auth.

### 1.2 The field contract

`Build Alert` in the workflow already emits exactly what `Alert.fromFirestore`
reads. Two rules keep them compatible if you edit either side:

- **`createdAt` must be written as `timestampValue`.** As a `stringValue` it is
  not a real `Timestamp`, so `Timestamp.toDate()` returns null and every card
  reads "Unknown time".
- **A document with no `createdAt` never appears at all.** The app queries
  `orderBy('createdAt')`, and Firestore excludes documents missing the ordered
  field. This fails silently — no error, the alert is just invisible.

### 1.3 No composite index needed

Ordering by a single field uses Firestore's automatic index, so
`firestore.indexes.json` is intentionally empty. If you later add a filter
server-side (e.g. `where('priority', ...)` **plus** the `orderBy`), Firestore
will demand a composite index and log a console link to create it.

---

## Part 2 — n8n credentials

### 2.1 OpenAI (3 nodes)

Get a key at <https://platform.openai.com/api-keys>, then in n8n:
**Credentials → New → OpenAi account**, paste the key.

Assign it to **WhatsApp AI Model**, **Analyze Image**, and **Transcribe Audio**.
If you only care about text messages, the last two can stay unconfigured — the
text branch runs without them.

### 2.2 Google service account (the Firestore write)

**a. Create the account**

<https://console.cloud.google.com/iam-admin/serviceaccounts?project=whatsapp-ai-agent-waseem>

→ **Create service account** → name it `n8n-tulip-alerts` → **Create and continue**.

**b. Grant the role**

Select role **Cloud Datastore User** (`roles/datastore.user`). That allows
reading and writing Firestore documents and nothing else — don't grant Owner or
Editor here.

**c. Create a JSON key**

Open the account → **Keys → Add key → Create new key → JSON**. A file downloads
containing `client_email` and `private_key`.

> 🔐 Treat this file like a password. It grants database write access, it is not
> covered by security rules, and it must never be committed to git. Delete it
> from your Downloads folder once pasted into n8n.

**d. Add it to n8n**

**Credentials → New → Google Service Account API**:

| Field | Value |
|---|---|
| Service Account Email | the `client_email` from the JSON |
| Private Key | the `private_key` value, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |
| Scope(s) | `https://www.googleapis.com/auth/datastore` |
| Impersonate a User | leave **off** |

The scope is the step people miss — without `datastore`, the token is issued but
Firestore rejects the write with `403 PERMISSION_DENIED`.

**e. Assign it**

Open **Create Firestore Alert** → Credential for Google API → pick the new one.

### 2.3 Point WhatsApp at the webhook

Activate the workflow, copy the **production** URL from the Webhook node
(`…/webhook/whatsapp-incoming`), and register it with Evolution — including
`webhookBase64: true`, or the image and audio branches receive nothing.
The exact `curl` is in [`n8n/README.md`](n8n/README.md).

---

## Part 3 — Verify end to end

Run these in order; each isolates one layer.

**1. Can n8n write at all?** In n8n, open **Create Firestore Alert** and click
*Execute step* with pinned data, or fire the smoke-test `curl` from
`n8n/README.md`. A `200` with a `name:` field in the response means the service
account works.

**2. Did the document land correctly?**

```bash
firebase firestore:documents:list alerts --project whatsapp-ai-agent-waseem
```

Confirm `createdAt` shows as a timestamp, not a string.

**3. Can the app read it?** With `flutter run -d chrome` going, a new alert
should appear within a second, with no refresh.

### If something breaks

| Symptom | Cause |
|---|---|
| App shows red error card, `permission-denied` | Rules not deployed (Part 1.1) |
| App stuck on spinner, console says "Could not reach Cloud Firestore backend" | Network/firewall, not your code |
| Alert written but invisible in the app | `createdAt` missing or written as a string |
| Card shows "Unknown time" | `createdAt` written as `stringValue` |
| Badge is grey "Unknown" | `priority` is not exactly `urgent`/`high`/`medium` |
| n8n `403 PERMISSION_DENIED` | Missing `datastore` scope, or role is not Cloud Datastore User |
| n8n `401` | Private key pasted without its BEGIN/END lines |
