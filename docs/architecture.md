# Architecture Decisions

This document records the key architectural decisions made for this homelab infrastructure.

---

## ADR-001: LXC Containers over Virtual Machines

### Context
Need to run 15+ services on a single server with 32GB RAM.

### Decision
Use LXC containers (via Proxmox Helper Scripts) instead of full VMs.

### Rationale
- **Resource efficiency**: LXCs share the host kernel, using ~50% less memory than VMs
- **Startup time**: Containers start in seconds vs minutes for VMs
- **Backup simplicity**: Proxmox native backup works seamlessly with LXCs
- **Community support**: Helper scripts provide tested, one-click deployments

### Consequences
- Slightly less isolation than VMs (shared kernel)
- Some applications may require privileged containers
- GPU passthrough more complex than with VMs

---

## ADR-002: Shared PostgreSQL Database

### Context
Multiple applications (Immich, Nextcloud, n8n, Vaultwarden) require a database.

### Decision
Run a single PostgreSQL instance serving multiple databases instead of per-application databases.

### Rationale
- **Production-like**: Mirrors how databases are managed in enterprise environments
- **Backup simplicity**: Single `pg_dump` backs up all application data
- **Resource efficiency**: One database engine instead of multiple SQLite/embedded DBs
- **Operational skills**: Practice with real database administration

### Consequences
- Single point of failure for database-dependent services
- Need to manage database users and permissions
- Some applications may have specific PostgreSQL version requirements

---

## ADR-003: Traefik + Cloudflare Tunnel for Ingress

### Context
Need secure remote access to services without exposing home IP or opening ports.

### Decision
Use Cloudflare Tunnel for ingress, with Traefik as the internal reverse proxy.

### Rationale
- **Security**: No port forwarding required, no exposed home IP
- **SSL management**: Cloudflare handles certificate provisioning
- **Subdomain routing**: Clean URLs like `service.harmeetrai.com`
- **DDoS protection**: Cloudflare's edge network provides protection

### Consequences
- Dependency on Cloudflare (free tier)
- All traffic routes through Cloudflare
- Need to maintain tunnel configuration

---

## ADR-004: Tiered Storage Architecture

### Context
Have two storage tiers: 1TB NVMe (fast) and 48TB RAID (bulk).

### Decision
Use NVMe for performance-critical data (databases, cache, downloads) and RAID for bulk storage (media, photos, backups).

### Rationale
- **Performance**: Databases and cache benefit from NVMe speed
- **Capacity**: Media library needs bulk storage, not speed
- **Cost efficiency**: Don't waste expensive NVMe on cold data
- **Flexibility**: Bind mounts allow services to access both tiers

### Consequences
- Need to manage mount points for each LXC
- Some complexity in determining which data goes where
- Must ensure critical data is on appropriate tier

---

## ADR-005: Backblaze B2 for Off-site Backups

### Context
Need disaster recovery capability with off-site backups.

### Decision
Use Backblaze B2 with Restic for encrypted, deduplicated backups.

### Rationale
- **Cost**: ~$5/TB/month, significantly cheaper than AWS S3
- **Restic integration**: First-class B2 backend support
- **Encryption**: Client-side encryption before upload
- **Deduplication**: Only changed blocks are uploaded

### Consequences
- Restore speed limited by internet bandwidth
- Monthly cost scales with data stored
- Need to manage B2 credentials securely

---

## ADR-006: Prometheus + Grafana for Monitoring

### Context
Need visibility into service health and resource usage.

### Decision
Deploy Prometheus for metrics collection and Grafana for visualization.

### Rationale
- **Industry standard**: Same stack used in production environments
- **Extensibility**: Wide ecosystem of exporters and dashboards
- **Alerting**: Prometheus alertmanager for notifications
- **Resume value**: Demonstrates monitoring/observability skills

### Consequences
- Additional resource usage for monitoring stack
- Need to configure scrape targets for each service
- Dashboard maintenance required

---

## Future Considerations

### Kubernetes Migration
Current LXC-based architecture could migrate to K3s when:
- Adding a second node for high availability
- Need for more sophisticated orchestration
- Want to practice Kubernetes skills

### GPU Addition
When adding GPU for AI/ML workloads:
- Consider dedicated VM with GPU passthrough
- Or upgrade to a system with better IOMMU support
