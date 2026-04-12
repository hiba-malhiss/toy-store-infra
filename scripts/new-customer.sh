#!/usr/bin/env bash
# Usage: ./scripts/new-customer.sh <customer_name>
# Creates customers/<name>/.env from the template and brings the stack up.
set -euo pipefail

CUSTOMER=${1:?Usage: $0 <customer_name>}
DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$DIR/customers/$CUSTOMER/.env"

if [ -d "$DIR/customers/$CUSTOMER" ]; then
  echo "Customer '$CUSTOMER' already exists at customers/$CUSTOMER/"
  echo "Edit the .env there and run: ./scripts/update.sh $CUSTOMER"
  exit 1
fi

mkdir -p "$DIR/customers/$CUSTOMER"
cp "$DIR/.env.template" "$ENV_FILE"

echo ""
echo "Created customers/$CUSTOMER/.env from template."
echo "Fill in all values in that file, then run:"
echo ""
echo "  ./scripts/deploy.sh $CUSTOMER"
echo ""
