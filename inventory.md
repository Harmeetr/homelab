# LXC Inventory

## Quick Reference

### Running Containers (NOT managed by Terraform)

| ID | Service | IP | Port | Category | Notes |
|----|---------|-----|------|----------|-------|
| 104 | Traefik | 192.168.1.116 | 80,443 | Core | |
| 105 | PostgreSQL | 192.168.1.117 | 5432 | Core | |
| 106 | Redis | 192.168.1.118 | 6379 | Core | |
| 107 | Cloudflared | 192.168.1.120 | — | Core | |
| 108 | Immich | 192.168.1.121 | 2283 | Apps | [Mounts](#immich-storage-mounts) |
| 109 | n8n | 192.168.1.122 | 5678 | Apps | |
| 110 | Prometheus | 192.168.1.123 | 9090 | Monitoring | |
| 111 | Grafana | 192.168.1.124 | 3000 | Monitoring | |
| 113 | Homepage | 192.168.1.127 | 3000 | Apps | |
| 130 | Claude Agent | 192.168.1.126 | 22 | Dev | |

### New Containers (Managed by Terraform)

| ID | Service | IP | Port | Category | Status |
|----|---------|-----|------|----------|--------|
| 140 | Uptime Kuma | 192.168.1.150 | 3001 | Monitoring | Planned |
| 122 | Vikunja | 192.168.1.132 | 3456 | Apps | Planned |
| 123 | Linkwarden | 192.168.1.133 | 3000 | Apps | Planned |
| 124 | Actual Budget | 192.168.1.134 | 5006 | Apps | Planned |
| 126 | Miniflux | 192.168.1.136 | 8080 | Apps | Planned |

### Future Containers (No Helper Script Available)

| ID | Service | IP | Notes |
|----|---------|-----|-------|
| 112 | Authentik | 192.168.1.125 | No helper script - deploy via Docker |
| 131 | Ollama | 192.168.1.141 | Requires GPU passthrough |
| — | CrowdSec | — | Addon only - install on Traefik LXC |

### Media Stack (Future)

| ID | Service | IP | Port | Notes |
|----|---------|-----|------|-------|
| 114 | Jellyfin | 192.168.1.140 | 8096 | |
| 115 | Sonarr | 192.168.1.141 | 8989 | |
| 116 | Radarr | 192.168.1.142 | 7878 | |
| 117 | Prowlarr | 192.168.1.143 | 9696 | |
| 118 | qBittorrent | 192.168.1.144 | 8080 | |

---

## Service URLs

| Service | Internal | External |
|---------|----------|----------|
| Traefik | http://192.168.1.116:8080 | — |
| Immich | http://192.168.1.121:2283 | immich.harmeetrai.com |
| n8n | http://192.168.1.122:5678 | n8n.harmeetrai.com |
| Prometheus | http://192.168.1.123:9090 | prometheus.harmeetrai.com |
| Grafana | http://192.168.1.124:3000 | grafana.harmeetrai.com |
| Homepage | http://192.168.1.127:3000 | home.harmeetrai.com |
| Uptime Kuma | http://192.168.1.150:3001 | status.harmeetrai.com |
| Vikunja | http://192.168.1.132:3456 | tasks.harmeetrai.com |
| Linkwarden | http://192.168.1.133:3000 | links.harmeetrai.com |
| Actual Budget | http://192.168.1.134:5006 | budget.harmeetrai.com |
| Miniflux | http://192.168.1.136:8080 | rss.harmeetrai.com |

---

## Network Info

- **Subnet:** 192.168.1.0/24
- **Gateway:** 192.168.1.1
- **DNS:** 192.168.1.1
- **Bridge:** vmbr0

---

## ID Ranges

| Range | Category |
|-------|----------|
| 100-109 | Core Infrastructure |
| 110-119 | Media Stack |
| 120-129 | Apps |
| 130-139 | Development/AI |
| 140-149 | Monitoring |

---

## Immich Storage Mounts

LXC 108 uses bind mounts to leverage tiered storage:

| Container Path | Host Path | Storage | Purpose |
|----------------|-----------|---------|---------|
| `/opt/immich/upload` | `/Apollo/Photos/immich/upload` | RAID | Original photos/videos |
| `/opt/immich/thumbs` | `/mnt/pve/tesla/cache/immich/thumbs` | NVMe | Generated thumbnails |
| `/opt/immich/profile` | `/mnt/pve/tesla/cache/immich/profile` | NVMe | User profile images |
| `/opt/immich/encoded-video` | `/Apollo/Photos/immich/encoded-video` | RAID | Transcoded videos |

See [Deploy Immich Runbook](docs/runbooks/deploy-immich.md) for setup instructions.
