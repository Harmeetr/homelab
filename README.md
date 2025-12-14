# Homelab Infrastructure

Personal server infrastructure running 15+ self-hosted services for media management, file synchronization, workflow automation, and monitoring.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          PROXMOX HYPERVISOR (i7-6700K, 32GB)                    │
│                     Tesla (1TB NVMe): LXCs | Apollo (48TB RAID): Data           │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  CORE INFRASTRUCTURE                                                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐                           │
│  │ Traefik  │ │PostgreSQL│ │  Redis   │ │Cloudflare│                           │
│  │ Reverse  │ │ Database │ │  Cache   │ │  Tunnel  │                           │
│  │  Proxy   │ │  Server  │ │          │ │          │                           │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘                           │
│                                                                                 │
│  MONITORING            MEDIA STACK                 APPS STACK                   │
│  ┌──────────┐         ┌──────────────┐           ┌──────────────┐              │
│  │Prometheus│         │ Plex/Jellyfin│           │    Immich    │              │
│  │ Grafana  │         │ Radarr/Sonarr│           │  Nextcloud   │              │
│  └──────────┘         │   Prowlarr   │           │ n8n/Vaultwarden│            │
│                       └──────────────┘           └──────────────┘              │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    │    Cloudflare Tunnel + Traefik    │
                    │    *.harmeetrai.com routing       │
                    └───────────────────────────────────┘
```

## Services

### Core Infrastructure
| Service | Purpose | Port |
|---------|---------|------|
| **Traefik** | Reverse proxy with auto SSL | 80, 443 |
| **PostgreSQL** | Shared database server | 5432 |
| **Redis** | Caching and message queue | 6379 |
| **Cloudflared** | Secure tunnel for remote access | — |

### Monitoring
| Service | Purpose | Port |
|---------|---------|------|
| **Prometheus** | Metrics collection | 9090 |
| **Grafana** | Visualization dashboards | 3000 |

### Media Stack
| Service | Purpose | Port |
|---------|---------|------|
| **Plex** | Media streaming | 32400 |
| **Jellyfin** | Open-source media streaming | 8096 |
| **Radarr** | Movie management | 7878 |
| **Sonarr** | TV show management | 8989 |
| **Prowlarr** | Indexer management | 9696 |
| **qBittorrent** | Download client | 8080 |

### Apps Stack
| Service | Purpose | Port |
|---------|---------|------|
| **Immich** | Photo management | 2283 |
| **Nextcloud** | File sync and share | 443 |
| **n8n** | Workflow automation | 5678 |
| **Vaultwarden** | Password manager | 80 |

## Storage Architecture

| Storage | Type | Size | Purpose |
|---------|------|------|---------|
| **Tesla** | NVMe SSD | 1 TB | LXC root filesystems, databases, cache, downloads |
| **Apollo** | HDD RAID | 48 TB | Media library, photos, file storage, backups |

### Storage Layout
```
Tesla (NVMe - Fast)                 Apollo (RAID - Bulk)
/mnt/pve/tesla/                     /Apollo/
├── lxc/           # LXC disks      ├── Media/        # Movies, TV, Music
├── databases/                      ├── Photos/       # Immich originals
│   ├── postgresql/                 ├── Nextcloud/    # User files
│   └── redis/                      ├── Downloads/    # Completed downloads
├── cache/                          └── Backups/      # Local backup staging
│   ├── immich/
│   └── plex-transcode/
└── downloads/     # Active downloads
```

## Key Design Decisions

### 1. LXC Containers over VMs
- **50% less memory** usage compared to full VMs
- **Faster startup** (seconds vs minutes)
- **Native Proxmox backup** support
- **Community script support** via [Proxmox Helper Scripts](https://helper-scripts.com)

### 2. Shared PostgreSQL Database
- **Production-like architecture** — single database server serving multiple applications
- **Simplified backups** — one `pg_dump` covers all application data
- **Resource efficiency** — no duplicate database engines

### 3. Traefik + Cloudflare Tunnel
- **Zero port forwarding** — tunnel handles all ingress securely
- **Automatic SSL** — Cloudflare manages certificates
- **Clean subdomain routing** — `service.harmeetrai.com` for each service

### 4. Tiered Storage
- **NVMe for performance** — databases, cache, active downloads
- **RAID for capacity** — media library, photos, backups
- **Bind mounts** — services access data via mount points

## Backup Strategy

| Data | Method | Destination | Frequency |
|------|--------|-------------|-----------|
| PostgreSQL | `pg_dump` → Restic | Backblaze B2 | Daily |
| LXC configs | Proxmox backup | Local + B2 | Weekly |
| Photos | Restic | Backblaze B2 | Daily |
| Nextcloud files | Restic | Backblaze B2 | Daily |

## Network

All services are exposed via Cloudflare Tunnel through Traefik:

| URL | Service |
|-----|---------|
| `plex.harmeetrai.com` | Plex |
| `jellyfin.harmeetrai.com` | Jellyfin |
| `immich.harmeetrai.com` | Immich |
| `nextcloud.harmeetrai.com` | Nextcloud |
| `n8n.harmeetrai.com` | n8n |
| `grafana.harmeetrai.com` | Grafana |
| `vault.harmeetrai.com` | Vaultwarden |

## Hardware

| Component | Specification |
|-----------|---------------|
| **CPU** | Intel i7-6700K (4c/8t) |
| **RAM** | 32 GB DDR4 |
| **Boot Drive** | 256 GB NVMe |
| **Fast Storage** | 1 TB NVMe (Tesla) |
| **Bulk Storage** | 48 TB HDD RAID (Apollo) |
| **Hypervisor** | Proxmox VE 8.x |

## Future Improvements

- [ ] Migrate to Kubernetes (K3s) for orchestration
- [ ] Add second node for high availability
- [ ] Implement HashiCorp Vault for secrets management
- [ ] Add GPU for local AI/LLM inference

## Documentation

- [Architecture Decisions](docs/architecture.md)
- [Runbooks](docs/runbooks/)
  - [Backup & Restore](docs/runbooks/backup-restore.md)
  - [Adding New Services](docs/runbooks/add-new-service.md)

## Acknowledgments

- [Proxmox VE Helper Scripts](https://github.com/community-scripts/ProxmoxVE) — One-click LXC deployments
- [Traefik](https://traefik.io/) — Cloud-native reverse proxy
- [Cloudflare](https://cloudflare.com/) — DNS and tunnel services
