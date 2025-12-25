# Deploy Authentik SSO

**LXC ID:** 112  
**IP:** 192.168.1.125  
**URL:** `auth.harmeetrai.com`  
**Ports:** 9000 (HTTP), 9443 (HTTPS)

## Prerequisites

- Proxmox access
- PostgreSQL (LXC 105) running
- Traefik configured

## Step 1: Create LXC Container

```bash
# SSH to Proxmox
ssh root@proxmox.local

# Create LXC
pct create 112 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname authentik \
  --cores 2 \
  --memory 2048 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.125/24,gw=192.168.1.1 \
  --storage tesla \
  --rootfs tesla:8 \
  --features nesting=1 \
  --unprivileged 1 \
  --start 1

pct start 112
```

## Step 2: Create PostgreSQL Database

```bash
# On PostgreSQL LXC (105)
pct enter 105

sudo -u postgres psql << 'EOF'
CREATE DATABASE authentik;
CREATE USER authentik WITH ENCRYPTED PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;
\c authentik
GRANT ALL ON SCHEMA public TO authentik;
EOF

# Allow remote connection
echo "host    authentik    authentik    192.168.1.125/32    scram-sha-256" >> /etc/postgresql/*/main/pg_hba.conf
systemctl reload postgresql
```

## Step 3: Install Docker and Authentik

```bash
# Enter Authentik LXC
pct enter 112

# Install Docker
apt update && apt install -y curl pwgen
curl -fsSL https://get.docker.com | sh

# Create directories
mkdir -p /opt/authentik
cd /opt/authentik

# Generate secret key
AUTHENTIK_SECRET_KEY=$(pwgen -s 50 1)
echo "AUTHENTIK_SECRET_KEY=$AUTHENTIK_SECRET_KEY" > .env

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
services:
  redis:
    image: redis:alpine
    container_name: authentik-redis
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "redis-cli ping | grep PONG"]
      start_period: 20s
      interval: 30s
      retries: 5
      timeout: 3s

  server:
    image: ghcr.io/goauthentik/server:2024.10
    container_name: authentik-server
    restart: unless-stopped
    command: server
    environment:
      AUTHENTIK_SECRET_KEY: ${AUTHENTIK_SECRET_KEY}
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: 192.168.1.117
      AUTHENTIK_POSTGRESQL__USER: authentik
      AUTHENTIK_POSTGRESQL__NAME: authentik
      AUTHENTIK_POSTGRESQL__PASSWORD: your-secure-password
    volumes:
      - ./media:/media
      - ./custom-templates:/templates
    ports:
      - "9000:9000"
      - "9443:9443"
    depends_on:
      - redis

  worker:
    image: ghcr.io/goauthentik/server:2024.10
    container_name: authentik-worker
    restart: unless-stopped
    command: worker
    environment:
      AUTHENTIK_SECRET_KEY: ${AUTHENTIK_SECRET_KEY}
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: 192.168.1.117
      AUTHENTIK_POSTGRESQL__USER: authentik
      AUTHENTIK_POSTGRESQL__NAME: authentik
      AUTHENTIK_POSTGRESQL__PASSWORD: your-secure-password
    volumes:
      - ./media:/media
      - ./custom-templates:/templates
      - ./certs:/certs
    depends_on:
      - redis
EOF

# Start Authentik
docker compose up -d
```

## Step 4: Initial Setup

1. Access https://192.168.1.125:9000/if/flow/initial-setup/
2. Create admin user
3. Enable MFA (TOTP recommended)

## Step 5: Add Traefik Route

Add to `configs/traefik/services.yaml`:

```yaml
http:
  routers:
    authentik:
      rule: "Host(`auth.harmeetrai.com`)"
      service: authentik
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt

  services:
    authentik:
      loadBalancer:
        servers:
          - url: "http://192.168.1.125:9000"
```

## Step 6: Configure Traefik Forward Auth

Add middleware to `configs/traefik/services.yaml`:

```yaml
http:
  middlewares:
    authentik:
      forwardAuth:
        address: http://192.168.1.125:9000/outpost.goauthentik.io/auth/traefik
        trustForwardHeader: true
        authResponseHeaders:
          - X-authentik-username
          - X-authentik-groups
          - X-authentik-email
          - X-authentik-name
          - X-authentik-uid
          - X-authentik-jwt
          - X-authentik-meta-jwks
          - X-authentik-meta-outpost
          - X-authentik-meta-provider
          - X-authentik-meta-app
          - X-authentik-meta-version
```

## Step 7: Create Traefik Outpost in Authentik

1. Go to Admin → Applications → Outposts
2. Create new outpost:
   - Name: `traefik`
   - Type: `Proxy`
3. Note the outpost token for Traefik config

## Step 8: Protect Services

Add middleware to any service router:

```yaml
http:
  routers:
    grafana:
      rule: "Host(`grafana.harmeetrai.com`)"
      service: grafana
      middlewares:
        - authentik
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt
```

## Verification

```bash
# Check containers
docker ps | grep authentik

# Check logs
docker logs authentik-server

# Test authentication
curl -I https://auth.harmeetrai.com
```

## OIDC Integration Examples

### Grafana

```ini
[auth.generic_oauth]
enabled = true
name = Authentik
client_id = <from authentik>
client_secret = <from authentik>
scopes = openid profile email
auth_url = https://auth.harmeetrai.com/application/o/authorize/
token_url = https://auth.harmeetrai.com/application/o/token/
api_url = https://auth.harmeetrai.com/application/o/userinfo/
```

### Immich

```yaml
OAUTH_ENABLED: true
OAUTH_ISSUER_URL: https://auth.harmeetrai.com/application/o/immich/
OAUTH_CLIENT_ID: <from authentik>
OAUTH_CLIENT_SECRET: <from authentik>
```
