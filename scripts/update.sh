#!/usr/bin/env bash
# Rolling update for a customer — pulls new images and recreates changed containers.
# Called automatically by GitHub Actions after a new image is pushed.
# Usage: ./scripts/update.sh <customer_name> [service...]
#   ./scripts/update.sh alkatatib               # update all services
#   ./scripts/update.sh alkatatib backend       # update backend only
#   ./scripts/update.sh alkatatib store admin game  # update FE services only
set -euo pipefail

CUSTOMER=${1:?Usage: $0 <customer_name> [service...]}
shift
SERVICES=("$@")   # remaining args are service names (empty = all)

DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$DIR/customers/$CUSTOMER/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "No .env found for '$CUSTOMER'. Run: ./scripts/new-customer.sh $CUSTOMER"
  exit 1
fi

# Detect whether a custom domain is configured
CUSTOM_DOMAIN=$(grep '^CUSTOM_DOMAIN=' "$ENV_FILE" | cut -d '=' -f2 || true)
COMPOSE_FLAG="-f $DIR/docker-compose.yml"
if [ -n "${CUSTOM_DOMAIN:-}" ]; then
  echo "==> Custom domain detected: $CUSTOM_DOMAIN -- merging custom-domain override..."
  COMPOSE_FLAG="-f $DIR/docker-compose.yml -f $DIR/docker-compose.custom-domain.yml"
fi

COMPOSE="docker compose -p $CUSTOMER --env-file $ENV_FILE $COMPOSE_FLAG"
TOKEN_FILE="$DIR/.ghcr-token"

if [ -f "$TOKEN_FILE" ]; then
  echo "==> Logging in to GHCR..."
  cat "$TOKEN_FILE" | docker login ghcr.io -u hiba-malhiss --password-stdin
else
  echo "Warning: .ghcr-token not found — skipping docker login."
fi

echo "==> Pulling latest images for $CUSTOMER ${SERVICES[*]:-}..."
$COMPOSE pull "${SERVICES[@]}"

echo "==> Recreating containers..."
$COMPOSE up -d --remove-orphans "${SERVICES[@]}"

echo "==> Done. Stack '$CUSTOMER' updated."

# ── Deployment summary ────────────────────────────────────────
STORE_DOMAIN=$(grep '^STORE_DOMAIN=' "$ENV_FILE" | cut -d '=' -f2)
ADMIN_DOMAIN=$(grep '^ADMIN_DOMAIN=' "$ENV_FILE" | cut -d '=' -f2)
VPS_IP=$(curl -s --max-time 5 ifconfig.me || echo "unavailable")

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           Deployment Summary — $CUSTOMER"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  🌐 Store      https://${STORE_DOMAIN}/"
echo "║  🔧 Admin      https://${ADMIN_DOMAIN}/"
echo "║  🎮 Game       https://${STORE_DOMAIN}/game"
echo "║  🔌 API        https://${STORE_DOMAIN}/api"
echo "║  ❤️  Health     https://${STORE_DOMAIN}/api/actuator/health"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  🖥️  VPS IP     ${VPS_IP}"
echo "║  🐳 Portainer  https://portainer.kidotoysco.com"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
