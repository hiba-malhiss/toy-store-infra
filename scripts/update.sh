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

COMPOSE="docker compose -p $CUSTOMER --env-file $ENV_FILE -f $DIR/docker-compose.yml"
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
