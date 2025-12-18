# AGENTS.md

## Repository Type
Infrastructure documentation for homelab (Proxmox LXC containers, Traefik, PostgreSQL).
No build/test/lint commands - this is a documentation-only repository.

## File Types
- **Markdown**: Documentation, runbooks, architecture decisions
- **YAML**: Traefik routing config in `configs/traefik/services.yaml`

## Conventions
- LXC IDs: 100-109 (core), 110-119 (media), 120-129 (apps), 130-139 (dev), 140-149 (monitoring)
- URLs: `service.harmeetrai.com`
- IPs: 192.168.1.x (see `inventory.md` for assignments)
- Traefik routes: Add routers and services sections to `services.yaml`

## When Adding Services
1. Update `inventory.md` with LXC ID, IP, ports
2. Add Traefik route to `configs/traefik/services.yaml`
3. Update `README.md` services table if user-facing
4. Follow runbook: `docs/runbooks/add-new-service.md`
