# LXC Inventory

## Quick Reference

| ID | Service | IP | Status |
|----|---------|-----|--------|
| 104 | Traefik | 192.168.1.116 | Running |
| 105 | PostgreSQL | 192.168.1.117 | Running |
| 106 | Redis | 192.168.1.118 | Running |
| 107 | Cloudflared | 192.168.1.120 | Running |
| 108 | Immich | 192.168.1.121 | Running |
| 109 | n8n | 192.168.1.122 | Running |
| 110 | Prometheus | 192.168.1.123 | Running |
| 111 | Grafana | 192.168.1.124 | Running |
| — | Plex | — | Not installed |
| — | Jellyfin | — | Not installed |
| — | Radarr | — | Not installed |
| — | Sonarr | — | Not installed |
| — | Prowlarr | — | Not installed |
| — | qBittorrent | — | Not installed |
| — | Nextcloud | — | Not installed |
| — | Vaultwarden | — | Not installed |

---

## Detailed Information

### Core Infrastructure

#### Traefik (ID: 104)
- **IP:** 192.168.1.116
- **Ports:** 80, 443
- **Config:** `/etc/traefik/`
- **Notes:** Reverse proxy for all services

#### PostgreSQL (ID: 105)
- **IP:** 192.168.1.117
- **Port:** 5432
- **Databases:** immich, n8n (create as needed)
- **Notes:** Shared database server

#### Redis (ID: 106)
- **IP:** 192.168.1.118
- **Port:** 6379
- **Notes:** Cache for Immich

#### Cloudflared (ID: 107)
- **IP:** 192.168.1.120
- **Notes:** Tunnel to Cloudflare

---

### Apps Stack

#### Immich (ID: 108)
- **IP:** 192.168.1.121
- **Port:** 2283
- **URL:** immich.harmeetrai.com
- **Database:** PostgreSQL (immich)
- **Mounts:**
  - `/Apollo/Harmeet/photos` → `/mnt/photos`

#### n8n (ID: 109)
- **IP:** 192.168.1.122
- **Port:** 5678
- **URL:** n8n.harmeetrai.com
- **Database:** PostgreSQL (n8n)
- **Notes:** Workflow automation

---

### Monitoring

#### Prometheus (ID: 110)
- **IP:** 192.168.1.123
- **Port:** 9090
- **Notes:** Metrics collection

#### Grafana (ID: 111)
- **IP:** 192.168.1.124
- **Port:** 3000
- **URL:** grafana.harmeetrai.com
- **Notes:** Dashboards

---

## Service URLs (After Traefik + Cloudflare Setup)

| Service | Internal URL | External URL |
|---------|--------------|--------------|
| Traefik Dashboard | http://192.168.1.116:8080 | traefik.harmeetrai.com |
| Immich | http://192.168.1.121:2283 | immich.harmeetrai.com |
| n8n | http://192.168.1.122:5678 | n8n.harmeetrai.com |
| Prometheus | http://192.168.1.123:9090 | prometheus.harmeetrai.com |
| Grafana | http://192.168.1.124:3000 | grafana.harmeetrai.com |

---

## Network Info

- **Subnet:** 192.168.1.0/24
- **Gateway:** 192.168.1.1 (assumed)
- **DNS:** 192.168.1.1 (assumed)

---

## Credentials

**Store securely in Vaultwarden once installed!**

| Service | Username | Password Location |
|---------|----------|-------------------|
| PostgreSQL | postgres | TBD |
| Grafana | admin | TBD |
| n8n | — | TBD |
| Immich | — | TBD |
