#!/usr/bin/env bash
# Tear down a customer's stack.
# Usage: ./scripts/remove.sh <customer_name> [--drop-db]
#   --drop-db   Drop the customer's database from the shared MySQL instance
set -euo pipefail

CUSTOMER=${1:?Usage: $0 <customer_name> [--drop-db]}
DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$DIR/customers/$CUSTOMER/.env"
DROP_DB=false

if [[ "${2:-}" == "--drop-db" ]]; then
  DROP_DB=true
  echo "WARNING: This will drop the database for '$CUSTOMER' from the shared MySQL instance."
  read -r -p "Type the customer name to confirm: " CONFIRM
  if [ "$CONFIRM" != "$CUSTOMER" ]; then
    echo "Aborted."
    exit 1
  fi
fi

docker compose \
  -p "$CUSTOMER" \
  --env-file "$ENV_FILE" \
  -f "$DIR/docker-compose.yml" \
  down

echo "==> Stack '$CUSTOMER' removed."

if [ "$DROP_DB" = true ]; then
  DB_ROOT_PW=$(grep '^DB_ROOT_PASSWORD=' "$DIR/database/.env" | cut -d '=' -f2)
  DB_NAME=$(grep '^DB_NAME=' "$ENV_FILE" | cut -d '=' -f2)
  if [ -n "$DB_ROOT_PW" ] && docker ps --format '{{.Names}}' | grep -q '^shared-mysql$'; then
    echo "Dropping database $DB_NAME from shared MySQL..."
    docker exec shared-mysql mysql -u root -p"$DB_ROOT_PW" \
      -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null
    echo "Done."
  else
    echo "WARNING: shared-mysql not running — database not dropped."
    echo "  Drop manually: docker exec shared-mysql mysql -u root -p<ROOT_PW> -e \"DROP DATABASE IF EXISTS $DB_NAME;\""
  fi
fi
