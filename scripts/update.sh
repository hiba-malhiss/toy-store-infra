#!/usr/bin/env bash
# Rolling update for a customer — pulls new images and recreates changed containers.
# Called automatically by GitHub Actions after a new image is pushed.
# Usage: ./scripts/update.sh <customer_name>
set -euo pipefail

CUSTOMER=${1:?Usage: $0 <customer_name>}
DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$DIR/customers/$CUSTOMER/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "No .env found for '$CUSTOMER'. Run: ./scripts/new-customer.sh $CUSTOMER"
  exit 1
fi

echo "==> Pulling latest images for $CUSTOMER..."
docker compose \
  -p "$CUSTOMER" \
  --env-file "$ENV_FILE" \
  -f "$DIR/docker-compose.yml" \
  pull

echo "==> Recreating changed containers..."
docker compose \
  -p "$CUSTOMER" \
  --env-file "$ENV_FILE" \
  -f "$DIR/docker-compose.yml" \
  up -d --remove-orphans

echo "==> Done. Stack '$CUSTOMER' updated."
