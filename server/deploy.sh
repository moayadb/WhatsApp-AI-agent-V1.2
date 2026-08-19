#!/usr/bin/env bash
#
# Deploy the Multi-Channel AI Analyzer on a Linux host (Contabo).
#
#   ./deploy.sh app.example.com
#
# Idempotent: safe to re-run for updates. Existing secrets and the database
# volume are left alone.
set -euo pipefail

DOMAIN="${1:-}"

if [[ -z "$DOMAIN" ]]; then
  echo "usage: ./deploy.sh <domain>" >&2
  echo "   e.g. ./deploy.sh app.example.com" >&2
  exit 1
fi

cd "$(dirname "$0")"

# ---------------------------------------------------------------- prechecks
command -v docker >/dev/null || {
  echo "docker is not installed. On Debian/Ubuntu:" >&2
  echo "  curl -fsSL https://get.docker.com | sh" >&2
  exit 1
}
docker compose version >/dev/null 2>&1 || {
  echo "the docker compose plugin is missing (apt install docker-compose-plugin)" >&2
  exit 1
}

if [[ ! -d web ]]; then
  echo "WARNING: ./web is empty — the app UI will 404." >&2
  echo "  Build it on your machine and copy it up:" >&2
  echo "    flutter build web --release" >&2
  echo "    scp -r build/web/* USER@HOST:$(pwd)/web/" >&2
  echo
fi

# ------------------------------------------------------------------- secrets
# Generated once and never regenerated: rotating JWT_SECRET signs everyone out,
# and rotating INTERNAL_TOKEN cuts the API off from the WhatsApp service.
if [[ ! -f .env ]]; then
  echo "creating .env with fresh secrets"
  PGPW="$(openssl rand -hex 16)"
  cat > .env <<EOF
APP_DOMAIN=${DOMAIN}

POSTGRES_USER=analyzer
POSTGRES_PASSWORD=${PGPW}
POSTGRES_DB=analyzer
DATABASE_URL=postgres://analyzer:${PGPW}@db:5432/analyzer

JWT_SECRET=$(openssl rand -hex 32)
INTERNAL_TOKEN=$(openssl rand -hex 32)
N8N_WEBHOOK_SECRET=$(openssl rand -hex 32)

# Fill in after importing n8n/analyze-message.json and activating it.
# Until then the response-time and cold-lead detectors still work.
N8N_ANALYZE_URL=

FCM_SERVICE_ACCOUNT_FILE=
FCM_PROJECT_ID=

NODE_ENV=production
LOG_LEVEL=info
WORKER_INTERVAL_SECONDS=60
EOF
  chmod 600 .env
else
  echo "keeping existing .env (secrets and database untouched)"
  # Domain may legitimately change; everything else stays.
  sed -i "s|^APP_DOMAIN=.*|APP_DOMAIN=${DOMAIN}|" .env
fi

# --------------------------------------------------------------------- build
echo
echo "building and starting the stack…"
docker compose up -d --build

# --------------------------------------------------------------------- check
echo
echo "waiting for the API to answer…"
for i in $(seq 1 60); do
  if docker compose exec -T api node -e \
    "fetch('http://127.0.0.1:3000/api/health').then(r=>r.json()).then(j=>process.exit(j.ok?0:1)).catch(()=>process.exit(1))" \
    2>/dev/null; then
    echo "API healthy."
    break
  fi
  [[ $i -eq 60 ]] && {
    echo "API did not become healthy. Logs:" >&2
    docker compose logs --tail=40 api >&2
    exit 1
  }
  sleep 2
done

echo
docker compose ps
cat <<EOF

Deployed.

  App        https://${DOMAIN}
  Health     https://${DOMAIN}/api/health

Next:
  1. Open the app, register, and complete the intake conversation.
  2. Team tab -> connect a number -> enter it -> type the 8-character code into
     WhatsApp (Settings -> Linked devices -> Link with phone number instead).
  3. To enable the AI detectors, import n8n/analyze-message.json, point its
     "Raise alert" node at https://${DOMAIN}/api/hooks/n8n/alert with the
     N8N_WEBHOOK_SECRET from .env, then put its production webhook URL into
     N8N_ANALYZE_URL here and re-run this script.

Backups — the WhatsApp session credentials live in the database, so losing it
means every agent must re-link:
  docker compose exec -T db pg_dump -U analyzer analyzer | gzip > backup-\$(date +%F).sql.gz

Never run 'docker compose down -v' on this host: -v deletes the volume.
EOF
