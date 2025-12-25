# Deploy Uptime Kuma

**LXC ID:** 140  
**IP:** 192.168.1.150  
**URL:** `status.harmeetrai.com`  
**Port:** 3001

## Prerequisites

- Proxmox access
- Traefik configured

## Step 1: Create LXC Container

```bash
# SSH to Proxmox
ssh root@proxmox.local

# Create LXC using helper script
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/uptimekuma.sh)"

# Or manually:
pct create 140 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname uptime-kuma \
  --cores 1 \
  --memory 512 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.150/24,gw=192.168.1.1 \
  --storage tesla \
  --rootfs tesla:4 \
  --features nesting=1 \
  --unprivileged 1 \
  --start 1

pct start 140
```

## Step 2: Install Docker and Uptime Kuma

```bash
# Enter container
pct enter 140

# Install Docker
apt update && apt install -y curl
curl -fsSL https://get.docker.com | sh

# Create directory
mkdir -p /opt/uptime-kuma

# Create docker-compose.yml
cat > /opt/uptime-kuma/docker-compose.yml << 'EOF'
services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    ports:
      - "3001:3001"
    volumes:
      - ./data:/app/data
    restart: unless-stopped
EOF

# Start Uptime Kuma
cd /opt/uptime-kuma && docker compose up -d
```

## Step 3: Initial Setup

1. Access http://192.168.1.150:3001
2. Create admin account
3. Set timezone to America/Vancouver

## Step 4: Add Monitors

Add monitors for all services:

| Monitor Name | Type | URL/Host | Interval |
|-------------|------|----------|----------|
| Traefik | HTTP | https://traefik.harmeetrai.com | 60s |
| PostgreSQL | TCP | 192.168.1.117:5432 | 60s |
| Redis | TCP | 192.168.1.118:6379 | 60s |
| Immich | HTTP | https://immich.harmeetrai.com | 60s |
| n8n | HTTP | https://n8n.harmeetrai.com | 60s |
| Grafana | HTTP | https://grafana.harmeetrai.com | 60s |
| Homepage | HTTP | https://home.harmeetrai.com | 60s |
| Authentik | HTTP | https://auth.harmeetrai.com | 60s |

## Step 5: Configure Notifications

### Discord Webhook

1. Go to Settings → Notifications
2. Add Discord notification
3. Create webhook in Discord server settings
4. Paste webhook URL

### Slack

1. Create Slack app with incoming webhook
2. Add Slack notification type
3. Paste webhook URL

## Step 6: Add Traefik Route

Add to `configs/traefik/services.yaml`:

```yaml
http:
  routers:
    uptime-kuma:
      rule: "Host(`status.harmeetrai.com`)"
      service: uptime-kuma
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt

  services:
    uptime-kuma:
      loadBalancer:
        servers:
          - url: "http://192.168.1.150:3001"
```

## Step 7: Create Public Status Page

1. Go to Status Pages → New Status Page
2. Configure:
   - Title: "Homelab Status"
   - Slug: "status"
   - Theme: Auto
3. Add monitor groups:
   - Core Infrastructure (Traefik, PostgreSQL, Redis)
   - Applications (Immich, n8n, Grafana)
4. Publish

Public URL: `https://status.harmeetrai.com/status/status`

## Step 8: Add to Homepage Dashboard

Update Homepage config to show Uptime Kuma widget:

```yaml
- widget:
    type: uptimekuma
    url: http://192.168.1.150:3001
    slug: status
```

## Verification

```bash
# Check container
docker logs uptime-kuma

# Test API
curl http://192.168.1.150:3001/api/status-page/status
```

## Backup

```bash
# Backup data
cp -r /opt/uptime-kuma/data /backup/uptime-kuma-$(date +%Y%m%d)
```
