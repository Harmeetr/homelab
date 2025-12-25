# AGENTS.md

## Repository Type
Infrastructure-as-code for homelab (Proxmox LXC containers, Traefik, PostgreSQL).
Configs in `configs/` auto-deploy via GitHub Actions on push to `main`.

## File Types
- **Markdown**: Documentation, runbooks, architecture decisions
- **YAML**: Service configs in `configs/`, Ansible in `infrastructure/ansible/`

## GitOps Workflow
Configs are automatically deployed when pushed to `main`:
1. Push changes to `configs/` or `infrastructure/ansible/`
2. GitHub Actions triggers on self-hosted runner (LXC 130)
3. Ansible syncs configs to target LXCs
4. Services reload automatically

## Conventions
- LXC IDs: 100-109 (core), 110-119 (media), 120-129 (apps), 130-139 (dev), 140-149 (monitoring)
- URLs: `service.harmeetrai.com`
- IPs: 192.168.1.x (see `inventory.md` for assignments)
- Traefik routes: Add routers and services sections to `configs/traefik/services.yaml`
- GitOps-managed configs: Add to `configs/<service>/` and update Ansible inventory

## When Adding Services
1. Update `inventory.md` with LXC ID, IP, ports
2. Add Traefik route to `configs/traefik/services.yaml`
3. If GitOps-managed: Add config dir and update `infrastructure/ansible/inventory/hosts.yml`
4. Update `README.md` services table if user-facing
5. Follow runbook: `docs/runbooks/add-new-service.md`

## GitOps Setup
See `docs/runbooks/gitops-workflow.md` for runner setup and adding new managed services.
