# Decisions and traps

Environment behaviour and design choices that were expensive to discover. Each
entry exists because something failed in a way that was hard to diagnose.

---

## DO NOT UNDO

These look like mistakes. They are not.

| Thing | Why it is that way |
|---|---|
| `serve-web.js` binds all interfaces, not `127.0.0.1` | A WireGuard tunnel on the dev machine blocks browser→loopback; the LAN address is the working path. |
| `Caddyfile` has **no** `email` directive | `email {$ACME_EMAIL}` with the variable unset is a zero-argument directive; Caddy rejects the whole config and crash-loops. Caddy registers ACME anonymously instead. |
| `markOnlineOnConnect: false` in Baileys | Otherwise WhatsApp routes notifications to the linked device and the agent stops hearing their own messages. |
| Stream error **515** handled *before* the "is registered" check | 515 is the normal final step of pairing. Checking registration first makes a successful pairing look abandoned — the symptom is a pairing code that never resolves. |
| `docker-compose.yml` sets `com.docker.network.driver.mtu` | See MTU below. |
| Timer detectors use no AI | They must fire when the model is unavailable or the token budget is spent. |
| Alert attribution ids never round-trip through the model | `wa` keeps org/conversation/agent ids and attaches them itself, so a prompt edit can never mis-attribute an alert. |
| `resumeAll` retries for 5 minutes on boot | See boot-order below. |

---

## Environment traps

### MTU: containers must match the host uplink
Inside WSL2 the uplink is **1420**, but Docker networks default to 1500.
Setting `mtu` in `daemon.json` covers only the default bridge — **compose
creates its own network and ignores it**.

Failure mode is silent and awful: DNS resolves, TLS handshakes complete, then
bulk transfers hang forever. Baileys never finishes connecting and no pairing
code is issued, with no error anywhere.

Check with `cat /sys/class/net/eth0/mtu`; set `DOCKER_MTU` in `.env`. On a normal
server this is 1500 and the setting changes nothing.

### PostgreSQL 18 crashes on this machine; use 17
`initdb` dies with access violation `0xC0000005` at "performing post-bootstrap
initialization" — reproduced from two independent PG18 builds. PostgreSQL
**17.11** initialises and runs fine. Local cluster lives at `C:\Users\USER\pg17data`
on port **5433** (5433, not 5432, so the abandoned PG18 install cannot collide).

### Docker Desktop is broken here; Docker Engine in WSL works
Docker Desktop 29.7.2 crashes at startup: its Inference manager hands a Windows
path to a Unix-socket listener. Disabling the AI feature does not stop it.
Docker Engine installed directly inside WSL2 Ubuntu works and is closer to
production anyway.

### WireGuard blocks browser→WSL loopback
An active WireGuard tunnel (`AllowedIPs = 0.0.0.0/0`) captures traffic to WSL's
virtual subnet. Symptom: `curl` works, the browser does not; or it works right
after a WSL restart and dies minutes later. Container **outbound** internet is
unaffected — WhatsApp stayed connected throughout.

This is why local development runs as **native Windows processes** rather than
in WSL. It does not exist on the Linux server.

### PowerShell writes UTF-8 BOMs
`Set-Content -Encoding utf8` prefixes a byte-order mark. It has broken:
- a bash script (`cd` became an unknown command, so compose ran from `/`)
- `.secrets.local` (`^JWT_SECRET=` did not match line 1, API refused to boot)

Write files with `[System.IO.File]::WriteAllText(path, text, (New-Object System.Text.UTF8Encoding($false)))`.

### Service boot order
`wa` can start before Postgres is accepting connections. A resume that fails
once and gives up leaves every WhatsApp session dead **while channel rows still
read "connected"** — messages simply stop arriving. `resumeWithRetry()` now
retries every 5s for 5 minutes.

### Build outputs exist in two places
`server/*/dist/` is used by the native Windows stack; the Docker images compile
their own copy. Fixing a bug and rebuilding only one means the other still runs
the old code — this cost a full round trip on the 515 fix. Rebuild both.

---

## AI / n8n

### n8n returns an empty 200 on a rejected secret
A `throw` in a Code node does not produce a 4xx to the caller; the webhook
answers `200` with an empty body. Callers must treat an unparseable/empty body
as failure, not success.

### OpenRouter needs an explicit `max_tokens`
Without it, it reserves the model's maximum (65k) and returns
`402 — you requested up to 65536 tokens, but can only afford 25000`.
(Currently on OpenAI directly; kept in case of a fallback.)

### Do not let the model infer thresholds from anecdotes
First interview run set the response threshold to **360 minutes** because the
manager's *story* mentioned a client lost after six hours. The prompt now states
thresholds come only from numbers the manager explicitly gives, and the
interviewer must ask directly before finishing.

### The analyst leans toward matching a rule
Given a rule about "images showing a problem", a meaningless test image was
still flagged as a payment dispute. Expect over-eager matching; the DO NOT ALERT
section of the generated prompt is what keeps the feed quiet.

---

## Product decisions

- **Alerts are attributable or they are worthless.** Every alert carries agent,
  client, conversation. The n8n hook backfills missing ids from the conversation
  and refuses cross-tenant writes.
- **`awaiting_reply_since` is the whole response-time feature** — set when a
  client message arrives with nothing pending, cleared when staff reply. The
  worker only looks for rows where it is old.
- **Median, not mean**, for first-response time: one agent asleep for six hours
  would otherwise hide nine performing fine.
- **A cold lead is medium, never urgent.** Treating it as an emergency is how a
  feed becomes noise.
- **Consent is recorded per linked number** (`channels.consent_name/at`).
  Monitoring an employee's WhatsApp needs it, and retrofitting is expensive.
- **Baileys is the unofficial WhatsApp Web protocol.** It is the only way
  "link with phone number" exists, and it carries ban risk for the linked
  account. This is a deliberate, known trade-off.
- **History backfill is ignored** (`type !== 'notify'`). Scoring the backlog on
  first link would alert on months of old conversations. Consequence: messages
  sent while the service is down are lost, not replayed.
