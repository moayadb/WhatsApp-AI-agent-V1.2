# server/secrets/

Credential files the services read at runtime. This directory is gitignored —
nothing in it may ever be committed.

| File | Used by | How to obtain |
|---|---|---|
| `fcm-service-account.json` | `api` (push notifications) | Firebase console → project **whatsapp-ai-agent-waseem** → Project settings → Service accounts → **Generate new private key**. Save the downloaded JSON here under exactly this name. |

Then set in `server/.env.local` (native run) or `server/.env` (Docker):

```
FCM_SERVICE_ACCOUNT_FILE=C:/Users/USER/Desktop/Multi-Channel AI Analyzer/server/secrets/fcm-service-account.json
FCM_PROJECT_ID=whatsapp-ai-agent-waseem
```

(In Docker the path is `/run/secrets/fcm-service-account.json` — the compose
file already mounts this directory there.)

Push stays silently disabled while the file is absent; nothing breaks.
