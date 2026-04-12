#!/usr/bin/env bash
# First-time deploy for a customer. Pulls images and starts the stack.
# Usage: ./scripts/deploy.sh <customer_name>
set -euo pipefail

CUSTOMER=${1:?Usage: $0 <customer_name>}
DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$DIR/customers/$CUSTOMER/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "No .env found for '$CUSTOMER'. Run: ./scripts/new-customer.sh $CUSTOMER"
  exit 1
fi

echo "==> Pulling images for $CUSTOMER..."
docker compose \
  -p "$CUSTOMER" \
  --env-file "$ENV_FILE" \
  -f "$DIR/docker-compose.yml" \
  pull

echo "==> Starting stack for $CUSTOMER..."
docker compose \
  -p "$CUSTOMER" \
  --env-file "$ENV_FILE" \
  -f "$DIR/docker-compose.yml" \
  up -d

echo "==> Done. Stack '$CUSTOMER' is running."
docker compose -p "$CUSTOMER" ps
