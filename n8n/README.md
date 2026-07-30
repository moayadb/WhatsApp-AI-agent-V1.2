# Tulip Alerts – n8n WhatsApp workflow

`tulip-alerts-whatsapp.json` replaces the Chat Trigger with a real Webhook so
live WhatsApp messages drive the alert feed the Flutter app reads.

```
Webhook → Normalize → Route By Type ─┬─ image → binary → Analyze Image ─┐
                                     ├─ audio → binary → Transcribe    ─┼→ Unified
                                     └─ text  ────────────────────────  ┘   Message
                                                                             ↓
                        Firestore ← IF escalate? ← Build Alert ← AI Agent
```

## Import

1. n8n → **Workflows → Import from File** → pick `tulip-alerts-whatsapp.json`.
2. Set credentials on three nodes (they import empty):
   - **WhatsApp AI Model**, **Analyze Image**, **Transcribe Audio** → your OpenAI credential.
   - **Create Firestore Alert** → a *Google Firebase Cloud Firestore OAuth2* credential
     for project `whatsapp-ai-agent-waseem`.
3. **Save**, then **Activate**. Copy the production URL from the Webhook node —
   it ends in `/webhook/whatsapp-incoming`.

> The test URL (`/webhook-test/...`) only works while you have the editor open
> with "Listen for test event" running. Point WhatsApp at the **production** URL.

## Point WhatsApp at the webhook

### Evolution API (what your CRM stack uses)

Set the instance webhook to the n8n production URL and — importantly — enable
base64, or the image/audio branches receive nothing to convert:

```bash
curl -X POST "https://YOUR-EVOLUTION-HOST/webhook/set/YOUR_INSTANCE" \
  -H "apikey: $EVOLUTION_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"webhook":{"enabled":true,"url":"https://YOUR-N8N/webhook/whatsapp-incoming","webhookByEvents":false,"webhookBase64":true,"events":["MESSAGES_UPSERT"]}}'
```

`webhookBase64: true` is the setting that makes Evolution inline media as base64.

### Meta WhatsApp Business Cloud API

The normalizer already understands Meta's `entry[0].changes[0].value.messages[0]`
shape, so **text works out of the box**. Two caveats:

- Meta requires a `GET` verification handshake (`hub.challenge`) that this
  Webhook node does not answer — add a second Webhook node on `GET` returning
  `{{ $json.query['hub.challenge'] }}` if you go this route.
- Meta sends a media **id**, not base64. The image/audio branches would need an
  extra HTTP Request to `/v1/{media-id}` with your bearer token before the
  "To Binary" step. Text-only escalations need no changes.

## Field contract

`Build Alert` writes exactly the seven fields the Flutter `Alert` model reads:

| Field | Firestore type | Source |
|---|---|---|
| `priority` | `stringValue` | AI, clamped to `urgent`/`high`/`medium` |
| `reason` | `stringValue` | AI, ≤500 chars |
| `firstName` / `lastName` | `stringValue` | WhatsApp `pushName`, split on first space |
| `phone` | `stringValue` | sender JID, digits only, `+` prefixed |
| `message` | `stringValue` | text, image description, or audio transcript |
| `createdAt` | **`timestampValue`** | WhatsApp message time (RFC3339 UTC) |

**`createdAt` must be `timestampValue`, not `stringValue`.** Firestore only
stores a real `Timestamp` for the former; with a string, the app's
`Timestamp.toDate()` yields null and every card reads "Unknown time".

Priority is clamped on write, so a model that invents `"critical"` still lands
as a valid value instead of a grey `Unknown` badge.

## Notes on the design

- **`Unified Message`** is one extra Set node where the three branches converge.
  It exists so `Build Alert` can read the message text from a single stable node
  reference no matter which branch ran — otherwise it would need to guess.
- **Filtering happens before the write.** `Needs Escalation?` gates the Firestore
  call, so routine "what time do you close?" messages never become alerts.
- **Noise is dropped in `Normalize Message`**: own outbound messages
  (`fromMe`), group chats (`@g.us`), and non-message events (presence, delivery
  receipts) end the run early.
- The webhook answers **200 immediately** (`responseMode: onReceived`) so
  WhatsApp does not retry while the AI step is still thinking.

## Smoke test without WhatsApp

```bash
curl -X POST "https://YOUR-N8N/webhook/whatsapp-incoming" \
  -H "Content-Type: application/json" \
  -d '{"data":{"key":{"remoteJid":"5511987654321@s.whatsapp.net","fromMe":false,"id":"TEST1"},"pushName":"Maria Silva","message":{"conversation":"My roses arrived completely wilted and the wedding is tomorrow!"},"messageTimestamp":1753440000}}'
```

That should produce an `urgent` alert appearing live in the Flutter app.
Swapping the text for "what time do you close?" should produce no alert at all.
