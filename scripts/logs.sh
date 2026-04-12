#!/usr/bin/env bash
# Tail logs for a customer's service.
# Usage: ./scripts/logs.sh <customer_name> [service]
# Examples:
#   ./scripts/logs.sh alkatatib
#   ./scripts/logs.sh alkatatib backend
set -euo pipefail

CUSTOMER=${1:?Usage: $0 <customer_name> [service]}
SERVICE=${2:-}
DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$DIR/customers/$CUSTOMER/.env"

docker compose \
  -p "$CUSTOMER" \
  --env-file "$ENV_FILE" \
  -f "$DIR/docker-compose.yml" \
  logs -f $SERVICE
