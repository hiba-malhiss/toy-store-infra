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

# Detect whether a custom domain is configured for this customer
CUSTOM_DOMAIN=$(grep '^CUSTOM_DOMAIN=' "$ENV_FILE" | cut -d '=' -f2)
COMPOSE_FILES="-f $DIR/docker-compose.yml"

if [ -n "${CUSTOM_DOMAIN:-}" ]; then
  echo "==> Custom domain detected: $CUSTOM_DOMAIN -- merging custom-domain override..."
  COMPOSE_FILES="-f $DIR/docker-compose.yml -f $DIR/docker-compose.custom-domain.yml"
fi

echo "==> Pulling images for $CUSTOMER..."
# shellword-split COMPOSE_FILES intentionally here
# shellcheck disable=SC2086
docker compose \
  -p "$CUSTOMER" \
  --env-file "$ENV_FILE" \
  $COMPOSE_FILES \
  pull

echo "==> Starting stack for $CUSTOMER..."
docker compose \
  -p "$CUSTOMER" \
  --env-file "$ENV_FILE" \
  $COMPOSE_FILES \
  up -d

echo "==> Done. Stack '$CUSTOMER' is running."
docker compose -p "$CUSTOMER" ps
