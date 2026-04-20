# Toy Store Infra

Multi-tenant deployment infrastructure for the Toy Store platform. Each customer gets a fully isolated Docker stack (backend, store, admin, game) served through a shared Traefik reverse proxy with automatic HTTPS.

---

## Architecture Overview

```
Internet
   │
   ▼
Traefik (port 80/443)  ←  shared reverse proxy, one instance on the VPS
   │
   ├── {customer}.alkatatib.cloud/         → store  (React)
   ├── {customer}.alkatatib.cloud/game     → game   (React, /game stripped before forwarding)
   ├── {customer}.alkatatib.cloud/api      → backend (Spring Boot :8080)
   └── admin-{customer}.alkatatib.cloud/   → admin  (React, separate subdomain)

Per-customer isolated stack (docker compose project = customer name):
  {customer}-mysql    MySQL 8.0  (data at /opt/toy-store-data/{customer}/mysql)
  {customer}-redis    Redis 7
  {customer}-backend  Spring Boot  (image from ghcr.io)
  {customer}-store    Nginx serving React store
  {customer}-admin    Nginx serving React admin panel
  {customer}-game     Nginx serving React game
```

All customer containers share the `traefik-public` Docker network so Traefik can route to them.
Each stack also has its own private `customer-net` network for internal service communication.

---

## Repository Structure

```
toy-store-infra/
├── docker-compose.yml          # Customer stack template (never run directly)
├── .env.template               # Documented template — read this to understand all vars
├── .env.defaults               # Pre-filled shared defaults — basis for every new customer
├── .gitignore
├── customers/
│   ├── .gitkeep
│   └── {customer_name}/
│       └── .env                # Per-customer secrets (gitignored, never committed)
├── scripts/
│   ├── new-customer.sh         # Scaffold a new customer env
│   ├── deploy.sh               # First-time deploy
│   ├── update.sh               # Rolling update (used by CI)
│   ├── remove.sh               # Tear down a stack
│   └── logs.sh                 # Tail logs
└── traefik/
    ├── docker-compose.yml      # Traefik + Portainer (run once, not per-customer)
    ├── traefik.yml             # Traefik static config
    └── acme.json               # TLS certs managed by Traefik (gitignored)
```

---

## One-Time Server Setup (Traefik)

Run this **once** when setting up a fresh VPS. Never repeat per customer.

```bash
cd /opt/toy-store-infra/traefik

# Create cert storage file with correct permissions
touch acme.json && chmod 600 acme.json

# Create the shared Docker network all stacks attach to
docker network create traefik-public

# Start Traefik + Portainer
docker compose up -d
```

Portainer is available at `https://portainer.alkatatib.cloud` (basic auth protected).

---

## Adding a New Customer

### 1. DNS

Add two A records pointing to the VPS IP:

| Record | Value |
|--------|-------|
| `{customer}.alkatatib.cloud` | VPS IP |
| `admin-{customer}.alkatatib.cloud` | VPS IP |

### 2. Scaffold the customer env

```bash
cd /opt/toy-store-infra
./scripts/new-customer.sh {customer_name}
```

This copies `.env.defaults`, auto-fills `CUSTOMER_NAME`, `STORE_DOMAIN`, and `ADMIN_DOMAIN`,
and writes the result to `customers/{customer_name}/.env`.

### 3. Review and fill the generated .env

```bash
nano customers/{customer_name}/.env
```

Fields that must be set (not pre-filled by defaults):

- `DB_USER`, `DB_ROOT_PASSWORD`, `DB_PASSWORD` — choose strong passwords
- `JWT_SECRET`, `CART_TOKEN_SECRET`, `APP_RATE_LIMIT_HMAC_SECRET` — generate with:
  ```bash
  openssl rand -hex 32
  ```
- Brevo (email) and Cloudinary (storage) — copy from shared account or create per-customer

### 4. First deploy

```bash
./scripts/deploy.sh {customer_name}
```

Pulls all Docker images from GHCR and starts the stack.
Traefik will automatically issue a Let's Encrypt TLS cert for both domains.

---

## Updating a Customer (Rolling Update)

Pull the latest images and recreate changed containers:

```bash
# Update all services
./scripts/update.sh {customer_name}

# Update specific services only
./scripts/update.sh {customer_name} backend
./scripts/update.sh {customer_name} store admin game
```

This is also triggered automatically by **GitHub Actions** after a new image is pushed to GHCR.

---

## Environment Variables

### Where they live

| File | Purpose |
|------|---------|
| `.env.template` | Full documented reference for every variable |
| `.env.defaults` | Shared pre-filled values used as base for new customers |
| `customers/{name}/.env` | Live secrets for a specific customer (gitignored) |

### Updating a secret for an existing customer

1. Edit the customer env file:
   ```bash
   nano /opt/toy-store-infra/customers/{customer_name}/.env
   ```
2. Recreate the affected container:
   ```bash
   ./scripts/update.sh {customer_name} backend   # or whichever service uses the changed var
   ```

### Updating a shared default

Edit `.env.defaults`. This only affects **new** customers created after the change.
Existing customer `.env` files are independent copies and are not touched.

---

## GHCR Token (Docker Pull Secret)

Docker images are hosted as private packages on the GitHub Container Registry (`ghcr.io`).
Pulling them requires a GitHub Personal Access Token with `read:packages` scope.

### Where it is stored

```
/opt/toy-store-infra/.ghcr-token
```

Plain text file, gitignored, never committed.

### How it is used

`deploy.sh` and `update.sh` read this file before pulling images:

```bash
cat .ghcr-token | docker login ghcr.io -u hiba-malhiss --password-stdin
```

### Rotating the token

1. Go to GitHub → Settings → Developer settings → Personal access tokens
2. Generate a new token with `read:packages` scope
3. Update the file on the server:
   ```bash
   echo "ghp_YOUR_NEW_TOKEN" > /opt/toy-store-infra/.ghcr-token
   chmod 600 /opt/toy-store-infra/.ghcr-token
   ```
4. Verify it works:
   ```bash
   cat /opt/toy-store-infra/.ghcr-token | docker login ghcr.io -u hiba-malhiss --password-stdin
   ```

---

## Removing a Customer

```bash
# Remove stack, keep database volumes
./scripts/remove.sh {customer_name}

# Remove stack AND permanently delete all data
./scripts/remove.sh {customer_name} --volumes
```

The `--volumes` flag requires you to type the customer name to confirm before deleting.

---

## Viewing Logs

```bash
# All services
./scripts/logs.sh {customer_name}

# Specific service
./scripts/logs.sh {customer_name} backend
./scripts/logs.sh {customer_name} store
```

---

## Docker Images

Images are built and pushed to GHCR by GitHub Actions.
Each customer gets its own image tag matching the customer name:

| Service | Image |
|---------|-------|
| Backend | `ghcr.io/hiba-malhiss/toy-store-backend:{customer_name}` |
| Store | `ghcr.io/hiba-malhiss/toy-store-store:{customer_name}` |
| Admin | `ghcr.io/hiba-malhiss/toy-store-admin:{customer_name}` |
| Game | `ghcr.io/hiba-malhiss/toy-store-game:{customer_name}` |

---

## Existing Customers

| Customer | Store | Admin |
|----------|-------|-------|
| `alkatatib` | https://alkatatib.alkatatib.cloud | https://admin-alkatatib.alkatatib.cloud |
| `test-customer` | https://test-customer.alkatatib.cloud | https://admin-test-customer.alkatatib.cloud |

---

## Useful Commands

```bash
# Check running containers for a customer
docker compose -p {customer_name} ps

# Check all running containers across all stacks
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Inspect Traefik routing logs
docker logs traefik

# Restart a single service without full redeploy
docker compose -p {customer_name} \
  --env-file customers/{customer_name}/.env \
  -f docker-compose.yml \
  restart backend
```

---

## Rotating Secrets & Passwords

### Database passwords (DB_PASSWORD / DB_ROOT_PASSWORD)

Changing the DB password requires updating both the `.env` file and the running MySQL container,
otherwise the backend will fail to connect.

```bash
# 1. Update the .env
nano /opt/toy-store-infra/customers/{customer_name}/.env
# Edit DB_PASSWORD and/or DB_ROOT_PASSWORD

# 2. Update the password inside MySQL
docker exec -it {customer_name}-mysql mysql -u root -p{OLD_ROOT_PASSWORD} \
  -e "ALTER USER 'user'@'%' IDENTIFIED BY '{NEW_PASSWORD}'; FLUSH PRIVILEGES;"

# 3. Recreate backend (and mysql) to pick up the new env vars
./scripts/update.sh {customer_name} mysql backend
```

### JWT / Cart / HMAC secrets (app secrets)

These are only read at backend startup, so a simple container recreate is enough:

```bash
# 1. Generate a new secret
openssl rand -hex 32

# 2. Update the .env
nano /opt/toy-store-infra/customers/{customer_name}/.env
# Paste the new value for JWT_SECRET, CART_TOKEN_SECRET, or APP_RATE_LIMIT_HMAC_SECRET

# 3. Recreate the backend
./scripts/update.sh {customer_name} backend
```

Note: rotating JWT_SECRET will invalidate all active user sessions (everyone gets logged out).

### GHCR token (Docker pull token)

See the **GHCR Token** section above for the full rotation steps.

### Brevo (email) credentials

```bash
# 1. Get new credentials from https://app.brevo.com → SMTP & API → SMTP
# 2. Update .env
nano /opt/toy-store-infra/customers/{customer_name}/.env
# Edit BREVO_SMTP_PASSWORD and/or BREVO_API_KEY

# 3. Restart backend
./scripts/update.sh {customer_name} backend
```

### Cloudinary credentials

```bash
# 1. Get keys from https://cloudinary.com/console
# 2. Update .env
nano /opt/toy-store-infra/customers/{customer_name}/.env
# Edit CLOUDINARY_API_KEY and CLOUDINARY_API_SECRET

# 3. Restart backend
./scripts/update.sh {customer_name} backend
```

### VPS root password

Change directly on the VPS (or via your hosting provider's panel):

```bash
passwd root
```

Update the password in any CI/CD secrets or documentation that references it.
