#!/usr/bin/env bash
# Usage: ./scripts/new-customer.sh <customer_name>
# Creates customers/<name>/.env from .env.defaults with CUSTOMER_NAME and
# STORE_DOMAIN auto-filled, then prints the next step.
set -euo pipefail

CUSTOMER=${1:?Usage: $0 <customer_name>}
BASE_DOMAIN="alkatatib.cloud"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$DIR/customers/$CUSTOMER/.env"
DEFAULTS="$DIR/.env.defaults"

if [ -d "$DIR/customers/$CUSTOMER" ]; then
  echo "Customer '$CUSTOMER' already exists — skipping .env creation."
  exit 0
fi

if [ ! -f "$DEFAULTS" ]; then
  echo "Missing .env.defaults — cannot create customer env."
  exit 1
fi

mkdir -p "$DIR/customers/$CUSTOMER"

# Copy defaults and substitute CUSTOMER_NAME + STORE_DOMAIN
sed \
  -e "s/^CUSTOMER_NAME=$/CUSTOMER_NAME=$CUSTOMER/" \
  -e "s/^STORE_DOMAIN=$/STORE_DOMAIN=$CUSTOMER.$BASE_DOMAIN/" \
  "$DEFAULTS" > "$ENV_FILE"

echo ""
echo "Created customers/$CUSTOMER/.env"
echo "  CUSTOMER_NAME = $CUSTOMER"
echo "  STORE_DOMAIN  = $CUSTOMER.$BASE_DOMAIN"
echo ""
echo "Make sure DNS record exists: $CUSTOMER.$BASE_DOMAIN → your VPS IP"
echo ""
echo "Then run:"
echo "  ./scripts/deploy.sh $CUSTOMER"
echo ""
