# Deploy Immich

**LXC ID:** 108  
**IP:** 192.168.1.121  
**URL:** `immich.harmeetrai.com`  
**Port:** 2283

## Overview

Immich is deployed with bind mounts to leverage tiered storage:
- **Originals** → Apollo (RAID) for capacity and redundancy
- **Cache/Thumbnails** → Tesla (NVMe) for speed

This keeps the LXC root filesystem small while supporting large photo libraries.

## Storage Architecture

| Immich Path | Host Mount | Storage | Purpose |
|-------------|------------|---------|---------|
| `/opt/immich/upload` | `/Apollo/Photos/immich/upload` | RAID (48TB) | Original photos/videos |
| `/opt/immich/thumbs` | `/mnt/pve/tesla/cache/immich/thumbs` | NVMe | Generated thumbnails |
| `/opt/immich/profile` | `/mnt/pve/tesla/cache/immich/profile` | NVMe | User profile images |
| `/opt/immich/encoded-video` | `/Apollo/Photos/immich/encoded-video` | RAID | Transcoded videos |

## Prerequisites

- Proxmox access
- PostgreSQL database (LXC 105)
- Redis (LXC 106)
- Traefik configured

---

## Step 1: Create Storage Directories on Proxmox Host

```bash
# SSH to Proxmox
ssh root@proxmox.local

# Create directories on Apollo (bulk storage)
mkdir -p /Apollo/Photos/immich/{upload,encoded-video}

# Create directories on Tesla (fast cache)
mkdir -p /mnt/pve/tesla/cache/immich/{thumbs,profile}

# Set ownership for unprivileged LXC (UID 100000 = container root)
# Immich runs as UID 1000 inside container, maps to 101000 on host
chown -R 101000:101000 /Apollo/Photos/immich
chown -R 101000:101000 /mnt/pve/tesla/cache/immich
```

> **Note:** In unprivileged LXCs, container UID 1000 maps to host UID 101000 (100000 + 1000).

---

## Step 2: Create LXC Container

```bash
# Create LXC using helper script
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/immich.sh)"
```

During setup:
- **LXC ID:** 108
- **Hostname:** immich
- **Disk:** 15GB (only holds OS + Docker, data is on mounts)
- **RAM:** 4096MB (ML models need memory)
- **CPU:** 4 cores
- **IP:** 192.168.1.121/24
- **Gateway:** 192.168.1.1

---

## Step 3: Stop Container and Add Bind Mounts

```bash
# Stop container
pct stop 108

# Add bind mounts to LXC config
cat >> /etc/pve/lxc/108.conf << 'EOF'

# Immich storage mounts
mp0: /Apollo/Photos/immich/upload,mp=/opt/immich/upload
mp1: /mnt/pve/tesla/cache/immich/thumbs,mp=/opt/immich/thumbs
mp2: /mnt/pve/tesla/cache/immich/profile,mp=/opt/immich/profile
mp3: /Apollo/Photos/immich/encoded-video,mp=/opt/immich/encoded-video
EOF

# Start container
pct start 108
```

---

## Step 4: Verify Mounts Inside Container

```bash
# Enter container
pct enter 108

# Check mounts are available
df -h | grep immich
ls -la /opt/immich/

# Verify permissions (should be owned by immich user, typically UID 1000)
ls -la /opt/immich/upload
```

Expected output:
```
drwxr-xr-x 2 1000 1000 4096 ... upload
drwxr-xr-x 2 1000 1000 4096 ... thumbs
...
```

---

## Step 5: Configure Immich to Use Mount Paths

If the helper script installed Immich via Docker Compose, update the volume paths:

```bash
# Edit docker-compose.yml
nano /opt/immich/docker-compose.yml
```

Ensure volumes point to the mounted directories:

```yaml
services:
  immich-server:
    volumes:
      - /opt/immich/upload:/usr/src/app/upload
      - /opt/immich/thumbs:/usr/src/app/upload/thumbs
      - /opt/immich/encoded-video:/usr/src/app/upload/encoded-video
      - /opt/immich/profile:/usr/src/app/upload/profile
      - /etc/localtime:/etc/localtime:ro

  immich-machine-learning:
    volumes:
      - /opt/immich/model-cache:/cache
```

Restart Immich:

```bash
cd /opt/immich && docker compose down && docker compose up -d
```

---

## Step 6: Create PostgreSQL Database

```bash
# Enter PostgreSQL container
pct enter 105

# Create database
sudo -u postgres psql << 'EOF'
CREATE DATABASE immich;
CREATE USER immich WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE immich TO immich;
ALTER USER immich WITH SUPERUSER;
\q
EOF

exit
```

> **Note:** Immich requires superuser for pgvecto.rs extension. Alternatively, manually create the extension.

---

## Step 7: Configure External PostgreSQL

Edit Immich's `.env` file to use the shared PostgreSQL:

```bash
pct enter 108

# Edit environment
nano /opt/immich/.env
```

Update database settings:

```env
DB_HOSTNAME=192.168.1.117
DB_PORT=5432
DB_DATABASE_NAME=immich
DB_USERNAME=immich
DB_PASSWORD=your_secure_password
```

Restart Immich:

```bash
cd /opt/immich && docker compose down && docker compose up -d
```

---

## Step 8: Add Traefik Route

Already configured in `configs/traefik/services.yaml`:

```yaml
http:
  routers:
    immich:
      rule: "Host(`immich.harmeetrai.com`)"
      service: immich
      entryPoints:
        - websecure
      tls:
        certResolver: letsencrypt

  services:
    immich:
      loadBalancer:
        servers:
          - url: "http://192.168.1.121:2283"
```

---

## Verification

```bash
# Check Immich is running
pct enter 108
docker ps

# Check logs
docker logs immich_server

# Test upload directory is writable
touch /opt/immich/upload/test && rm /opt/immich/upload/test

# Verify storage locations from host
ssh root@proxmox.local
ls -la /Apollo/Photos/immich/upload/
ls -la /mnt/pve/tesla/cache/immich/thumbs/
```

Upload a test photo via the web UI and verify:
1. Original appears in `/Apollo/Photos/immich/upload/`
2. Thumbnail generated in `/mnt/pve/tesla/cache/immich/thumbs/`

---

## Backup

### What to Back Up

| Data | Location | Priority | Method |
|------|----------|----------|--------|
| Original photos | `/Apollo/Photos/immich/upload` | Critical | Restic to B2 |
| Database | PostgreSQL (LXC 105) | Critical | pg_dump |
| Thumbnails | `/mnt/pve/tesla/cache/immich/thumbs` | Low | Regenerable |
| Encoded video | `/Apollo/Photos/immich/encoded-video` | Low | Regenerable |

### Backup Commands

```bash
# Backup originals (run from Proxmox host)
restic -r b2:bucket-name backup /Apollo/Photos/immich/upload

# Backup database (run from PostgreSQL LXC)
pg_dump -U immich immich > /backup/immich-db-$(date +%Y%m%d).sql
```

> **Note:** Thumbnails and encoded videos can be regenerated by Immich. Only originals and database are critical.

---

## Troubleshooting

### Permission Denied on Uploads

```bash
# Check ownership on host
ls -la /Apollo/Photos/immich/

# Fix if needed (101000 = container UID 1000)
chown -R 101000:101000 /Apollo/Photos/immich
```

### Mount Not Visible in Container

```bash
# Verify mount in LXC config
cat /etc/pve/lxc/108.conf | grep mp

# Restart container
pct stop 108 && pct start 108
```

### Immich Can't Connect to PostgreSQL

```bash
# Test connection from Immich container
pct enter 108
apt install -y postgresql-client
psql -h 192.168.1.117 -U immich -d immich
```

---

## Storage Capacity Planning

| Library Size | Originals | Thumbnails (~15%) | Total Needed |
|--------------|-----------|-------------------|--------------|
| 100 GB | 100 GB | 15 GB | ~120 GB |
| 500 GB | 500 GB | 75 GB | ~600 GB |
| 1 TB | 1 TB | 150 GB | ~1.2 TB |
| 5 TB | 5 TB | 750 GB | ~6 TB |

Current capacity:
- **Apollo (originals):** 48 TB available
- **Tesla (cache):** 1 TB available (sufficient for ~6 TB library)
