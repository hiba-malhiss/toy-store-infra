#!/usr/bin/env bash
# Build frontend Docker images for a customer with their domain baked in.
# Run this whenever a customer is first created OR their domain changes.
# Usage: ./scripts/build.sh <customer_name>
set -euo pipefail

CUSTOMER=${1:?Usage: $0 <customer_name>}
DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$DIR/customers/$CUSTOMER/.env"
REPO_DIR="/opt/toystore-repo/baby-toys-store"

if [ ! -f "$ENV_FILE" ]; then
  echo "No .env found for . Run: ./scripts/new-customer.sh $CUSTOMER"
  exit 1
fi

if [ ! -d "$REPO_DIR" ]; then
  echo "Source repo not found at $REPO_DIR"
  exit 1
fi

STORE_DOMAIN=$(grep "^STORE_DOMAIN=" "$ENV_FILE" | cut -d "=" -f2)
GITHUB_OWNER=$(grep "^GITHUB_OWNER=" "$ENV_FILE" | cut -d "=" -f2)
API_BASE_URL="https://$STORE_DOMAIN"

echo "==> Building images for customer: $CUSTOMER"
echo "    API base URL: $API_BASE_URL"
echo ""

echo "==> Building store-front..."
docker build \
  -f "$REPO_DIR/apps/store-front/Dockerfile" \
  --build-arg VITE_API_BASE_URL="$API_BASE_URL" \
  -t "ghcr.io/$GITHUB_OWNER/toy-store-store:$CUSTOMER" \
  "$REPO_DIR"

echo ""
echo "==> Building store-admin..."
docker build \
  -f "$REPO_DIR/apps/store-admin/Dockerfile" \
  --build-arg VITE_API_BASE_URL="$API_BASE_URL" \
  -t "ghcr.io/$GITHUB_OWNER/toy-store-admin:$CUSTOMER" \
  "$REPO_DIR"

echo ""
echo "==> Done. Images built:"
echo "    ghcr.io/$GITHUB_OWNER/toy-store-store:$CUSTOMER"
echo "    ghcr.io/$GITHUB_OWNER/toy-store-admin:$CUSTOMER"
echo ""
echo "Next: ./scripts/deploy.sh $CUSTOMER"
