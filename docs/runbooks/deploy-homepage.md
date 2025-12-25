# Deploy Homepage Dashboard

**LXC ID:** 129  
**IP:** 192.168.1.140  
**URL:** `home.harmeetrai.com`  
**Port:** 3000

## Prerequisites

- Proxmox access
- Traefik configured

## Step 1: Create LXC Container

```bash
# SSH to Proxmox host
ssh root@proxmox.local

# Create LXC using helper script
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/homepage.sh)"

# Or manually:
pct create 129 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname homepage \
  --cores 1 \
  --memory 512 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.140/24,gw=192.168.1.1 \
  --storage tesla \
  --rootfs tesla:4 \
  --features nesting=1 \
  --unprivileged 1 \
  --start 1

# Start container
pct start 129
```

## Step 2: Install Docker and Homepage

```bash
# Enter container
pct enter 129

# Install Docker
apt update && apt install -y curl
curl -fsSL https://get.docker.com | sh

# Create config directory
mkdir -p /opt/homepage/config

# Create docker-compose.yml
cat > /opt/homepage/docker-compose.yml << 'EOF'
services:
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    ports:
      - "3000:3000"
    volumes:
      - ./config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      PUID: 1000
      PGID: 1000
    restart: unless-stopped
EOF

# Start Homepage
cd /opt/homepage && docker compose up -d
```

## Step 3: Configure Homepage

```bash
# Create services configuration
cat > /opt/homepage/config/services.yaml << 'EOF'
- Core Infrastructure:
    - Traefik:
        href: https://traefik.harmeetrai.com
        icon: traefik.png
        description: Reverse Proxy
        server: my-docker
        container: traefik
    - PostgreSQL:
        href: http://192.168.1.117:5432
        icon: postgres.png
        description: Database Server
    - Redis:
        href: http://192.168.1.118:6379
        icon: redis.png
        description: Cache

- Applications:
    - Immich:
        href: https://immich.harmeetrai.com
        icon: immich.png
        description: Photo Management
    - n8n:
        href: https://n8n.harmeetrai.com
        icon: n8n.png
        description: Workflow Automation
    - Grafana:
        href: https://grafana.harmeetrai.com
        icon: grafana.png
        description: Monitoring Dashboards

- Monitoring:
    - Prometheus:
        href: https://prometheus.harmeetrai.com
        icon: prometheus.png
        description: Metrics Collection
    - Uptime Kuma:
        href: https://status.harmeetrai.com
        icon: uptime-kuma.png
        description: Status Page
EOF

# Create widgets configuration
cat > /opt/homepage/config/widgets.yaml << 'EOF'
- resources:
    cpu: true
    memory: true
    disk: /
- datetime:
    text_size: xl
    format:
      dateStyle: long
      timeStyle: short
      hourCycle: h12
EOF

# Create settings
cat > /opt/homepage/config/settings.yaml << 'EOF'
title: Homelab
background:
  image: https://images.unsplash.com/photo-1502790671504-542ad42d5189
  blur: sm
  opacity: 50
theme: dark
color: slate
headerStyle: clean
layout:
  Core Infrastructure:
    style: row
    columns: 3
  Applications:
    style: row
    columns: 3
  Monitoring:
    style: row
    columns: 3
EOF
```

## Step 4: Add Traefik Route

Add to `configs/traefik/services.yaml`:

```yaml
http:
  routers:
    homepage:
      rule: "Host(`home.harmeetrai.com`)"
      service: homepage
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt

  services:
    homepage:
      loadBalancer:
        servers:
          - url: "http://192.168.1.140:3000"
```

## Step 5: Add to Cloudflare Tunnel

```bash
# On cloudflared LXC (107)
# Add to config.yml:
ingress:
  - hostname: home.harmeetrai.com
    service: http://192.168.1.116:80
```

## Verification

```bash
# Test locally
curl http://192.168.1.140:3000

# Test via Traefik
curl -H "Host: home.harmeetrai.com" http://192.168.1.116
```

## Troubleshooting

```bash
# Check container logs
docker logs homepage

# Restart service
cd /opt/homepage && docker compose restart

# Check config syntax
docker exec homepage cat /app/config/services.yaml
```
