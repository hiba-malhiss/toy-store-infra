#!/usr/bin/env bash
# Usage: ./scripts/new-customer.sh <customer_name>
# Creates customers/<name>/.env from .env.defaults with CUSTOMER_NAME,
# STORE_DOMAIN, and ADMIN_DOMAIN auto-filled, then prints the next step.
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

# Copy defaults and substitute CUSTOMER_NAME, STORE_DOMAIN, ADMIN_DOMAIN, and DB_NAME
sed \
  -e "s/^CUSTOMER_NAME=$/CUSTOMER_NAME=$CUSTOMER/" \
  -e "s/^STORE_DOMAIN=$/STORE_DOMAIN=$CUSTOMER.$BASE_DOMAIN/" \
  -e "s/^ADMIN_DOMAIN=$/ADMIN_DOMAIN=admin-$CUSTOMER.$BASE_DOMAIN/" \
  -e "s/^DB_NAME=$/DB_NAME=toystore_$CUSTOMER/" \
  "$DEFAULTS" > "$ENV_FILE"

echo ""
echo "Created customers/$CUSTOMER/.env"
echo "  CUSTOMER_NAME = $CUSTOMER"
echo "  STORE_DOMAIN  = $CUSTOMER.$BASE_DOMAIN"
echo "  ADMIN_DOMAIN  = admin-$CUSTOMER.$BASE_DOMAIN"
echo "  DB_NAME       = toystore_$CUSTOMER"
echo ""

# Create the database in the shared MySQL instance
DB_ROOT_PW=$(grep '^DB_ROOT_PASSWORD=' "$DIR/database/.env" | cut -d '=' -f2)
if [ -n "$DB_ROOT_PW" ] && docker ps --format '{{.Names}}' | grep -q '^shared-mysql$'; then
  echo "Creating database toystore_$CUSTOMER in shared MySQL..."
  docker exec shared-mysql mysql -u root -p"$DB_ROOT_PW" \
    -e "CREATE DATABASE IF NOT EXISTS toystore_$CUSTOMER; GRANT ALL PRIVILEGES ON toystore_$CUSTOMER.* TO 'user'@'%'; FLUSH PRIVILEGES;" 2>/dev/null
  echo "Done."
else
  echo "WARNING: shared-mysql container not running — skip DB creation."
  echo "  Run manually after the database stack is up:"
  echo "  docker exec shared-mysql mysql -u root -p<ROOT_PW> -e \"CREATE DATABASE IF NOT EXISTS toystore_$CUSTOMER;\""
fi

echo ""
echo "Make sure these DNS A records point to your VPS IP:"
echo "  $CUSTOMER.$BASE_DOMAIN        → your VPS IP"
echo "  admin-$CUSTOMER.$BASE_DOMAIN  → your VPS IP"
echo ""
echo "Then run:"
echo "  ./scripts/deploy.sh $CUSTOMER"
echo ""
