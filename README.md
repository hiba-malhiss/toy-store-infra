# Toy Store Infra — Operations Guide

VPS IP: `82.180.155.197`

---

## Table of Contents
1. [Onboard a new customer](#1-onboard-a-new-customer)
2. [Change the VPS root password](#2-change-the-vps-root-password)
3. [Change the database password](#3-change-the-database-password)
4. [Change the Portainer password](#4-change-the-portainer-password)
5. [Change the PHPMyAdmin password](#5-change-the-phpmyadmin-password)
6. [Change the base domain](#6-change-the-base-domain)
7. [Add a custom domain for a customer](#7-add-a-custom-domain-for-a-customer)

---

## 1. Onboard a new customer

```bash
# Step 1 - create env + database
./scripts/new-customer.sh <customer_name>

# Step 2 - add DNS records at your registrar (or wildcard *.kidotoysco.com already covers it)
#   <customer_name>.kidotoysco.com        -> A -> 82.180.155.197
#   admin-<customer_name>.kidotoysco.com  -> A -> 82.180.155.197

# Step 3 - build frontend images with the customer domain baked in
./scripts/build.sh <customer_name>

# Step 4 - start the stack
./scripts/deploy.sh <customer_name>
```

URLs after deploy:
- Store: `https://<customer_name>.kidotoysco.com`
- Admin: `https://admin-<customer_name>.kidotoysco.com`
- Game:  `https://<customer_name>.kidotoysco.com/game`
- API:   `https://<customer_name>.kidotoysco.com/api`

---

## 2. Change the VPS root password

SSH into the VPS and run:

```bash
passwd root
# enter new password twice
```

> Keep the new password in a secure place. All deploy scripts and SSH access depend on it.

---

## 3. Change the database password

There are **two separate passwords** to update.

### 3a. MySQL root password
Used by PHPMyAdmin and by new-customer.sh to create databases.

```bash
# 1. Change it inside MySQL
docker exec shared-mysql mysql -u root -pOLD_PASSWORD \
  -e "ALTER USER root@localhost IDENTIFIED BY NEW_PASSWORD; FLUSH PRIVILEGES;"

# 2. Update the file
nano /opt/toy-store-infra/database/.env
#    change: DB_ROOT_PASSWORD=NEW_PASSWORD

# 3. Restart phpmyadmin to pick up new creds
cd /opt/toy-store-infra/database && docker compose up -d
```

### 3b. Per-customer app password (DB_PASSWORD)
Used by each customer Spring backend to connect to MySQL.

```bash
# 1. Change it inside MySQL
docker exec shared-mysql mysql -u root -pROOT_PASSWORD \
  -e "ALTER USER user@% IDENTIFIED BY NEW_PASSWORD; FLUSH PRIVILEGES;"

# 2. Update every customer .env file
nano /opt/toy-store-infra/customers/<customer_name>/.env
#    change: DB_PASSWORD=NEW_PASSWORD

# 3. Restart each backend
docker restart <customer_name>-backend
```

---

## 4. Change the Portainer password

Portainer is at https://portainer.kidotoysco.com

### Via the Portainer web UI (easiest)
1. Log in to https://portainer.kidotoysco.com
2. Click your username (top-right) -> My account -> Change password

### Via CLI (if locked out)
```bash
docker exec -it portainer /app/portainer --admin-password NEW_PASSWORD
docker restart portainer
```

### Change the Traefik HTTP basic-auth protecting /portainer
This is a separate auth layer in front of Portainer (username: admin).

```bash
# 1. Generate a new bcrypt hash
docker run --rm httpd:2.4-alpine htpasswd -nbB admin NEW_PASSWORD
# Output example:  admin:$2y$05$abc...

# 2. Double every $ sign in the hash (Docker Compose escaping rule)
#    $2y$05$abc  ->  $$2y$$05$$abc

# 3. Update traefik/docker-compose.yml
nano /opt/toy-store-infra/traefik/docker-compose.yml
#    update the basicauth.users line under portainer-auth middleware

# 4. Recreate the container
cd /opt/toy-store-infra/traefik && docker compose up -d --force-recreate portainer
```

---

## 5. Change the PHPMyAdmin password

PHPMyAdmin at https://phpmyadmin.kidotoysco.com is protected by Traefik HTTP basic auth (username: admin).

```bash
# 1. Generate a new bcrypt hash
docker run --rm httpd:2.4-alpine htpasswd -nbB admin NEW_PASSWORD
# Output example:  admin:$2y$05$abc...

# 2. Double every $ sign in the hash (Docker Compose escaping rule)
#    $2y$05$abc  ->  $$2y$$05$$abc

# 3. Update database/docker-compose.yml
nano /opt/toy-store-infra/database/docker-compose.yml
#    update the basicauth.users line under phpmyadmin-auth middleware

# 4. Recreate the container
cd /opt/toy-store-infra/database && docker compose up -d --force-recreate phpmyadmin
```

Note: PHPMyAdmin uses the MySQL root password to connect — change that in step 3a.

---

## 6. Change the base domain

Full walkthrough for switching from kidotoysco.com to newdomain.com.

### Step 1 - Update the new-customer script
```bash
nano /opt/toy-store-infra/scripts/new-customer.sh
# change: BASE_DOMAIN="kidotoysco.com"  ->  BASE_DOMAIN="newdomain.com"
```

### Step 2 - Update every customer .env
```bash
nano /opt/toy-store-infra/customers/<customer_name>/.env
# change STORE_DOMAIN and ADMIN_DOMAIN to use the new domain
```

### Step 3 - Update Portainer and PHPMyAdmin labels
```bash
nano /opt/toy-store-infra/traefik/docker-compose.yml
# change portainer.kidotoysco.com -> portainer.newdomain.com

nano /opt/toy-store-infra/database/docker-compose.yml
# change phpmyadmin.kidotoysco.com -> phpmyadmin.newdomain.com
```

### Step 4 - Update the deploy summary in update.sh
```bash
nano /opt/toy-store-infra/scripts/update.sh
# change portainer.kidotoysco.com -> portainer.newdomain.com
```

### Step 5 - Rebuild frontend images for each customer
The API URL is baked into the JS bundle at build time.
```bash
./scripts/build.sh <customer_name>
```

### Step 6 - Clear SSL cert cache and restart everything
```bash
# Reset cert storage so Traefik requests fresh certs for the new domain
echo "{}" > /opt/toy-store-infra/traefik/acme.json
chmod 600 /opt/toy-store-infra/traefik/acme.json

# Restart shared services
cd /opt/toy-store-infra/traefik   && docker compose up -d
cd /opt/toy-store-infra/database  && docker compose up -d

# Redeploy each customer stack
cd /opt/toy-store-infra
docker compose -p <customer_name> --env-file customers/<customer_name>/.env -f docker-compose.yml up -d
```

### Step 7 - Add DNS records at your registrar
```
*.newdomain.com          A  82.180.155.197   (wildcard covers all customers)
portainer.newdomain.com  A  82.180.155.197
phpmyadmin.newdomain.com A  82.180.155.197
```

Wait 5-30 minutes for DNS to propagate. Traefik auto-issues SSL certs once DNS resolves.

---

## 7. Add a custom domain for a customer

### Step 1 - Edit the customer .env
```bash
nano /opt/toy-store-infra/customers/<customer_name>/.env
# Add these two lines:
CUSTOM_DOMAIN=mystore.com
CUSTOM_ADMIN_DOMAIN=admin.mystore.com
```

### Step 2 - Redeploy the customer stack
deploy.sh auto-detects CUSTOM_DOMAIN and merges the extra Traefik routes.
```bash
./scripts/deploy.sh <customer_name>
```

### Step 3 - Customer adds DNS records at their registrar
```
mystore.com        A  82.180.155.197
admin.mystore.com  A  82.180.155.197
```

SSL cert for the custom domain is issued automatically once DNS propagates.
The original subdomain (<customer>.kidotoysco.com) continues to work as a fallback.
