#!/usr/bin/env bash
# Tear down a customer's stack. Volumes (database) are preserved unless --volumes is passed.
# Usage: ./scripts/remove.sh <customer_name> [--volumes]
set -euo pipefail

CUSTOMER=${1:?Usage: $0 <customer_name> [--volumes]}
DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$DIR/customers/$CUSTOMER/.env"
EXTRA_FLAGS=""

if [[ "${2:-}" == "--volumes" ]]; then
  echo "WARNING: This will delete all data (database) for '$CUSTOMER'."
  read -r -p "Type the customer name to confirm: " CONFIRM
  if [ "$CONFIRM" != "$CUSTOMER" ]; then
    echo "Aborted."
    exit 1
  fi
  EXTRA_FLAGS="--volumes"
fi

docker compose \
  -p "$CUSTOMER" \
  --env-file "$ENV_FILE" \
  -f "$DIR/docker-compose.yml" \
  down $EXTRA_FLAGS

echo "==> Stack '$CUSTOMER' removed."
