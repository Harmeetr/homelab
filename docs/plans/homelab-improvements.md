# Homelab Improvements - Implementation Plan

**Status:** In Progress  
**Created:** 2025-12-18  
**Last Updated:** 2025-12-18

## Overview

Comprehensive improvement plan covering infrastructure automation, security hardening, daily-use applications, and AI capabilities.

---

## Priority 1: Resume-Worthy Infrastructure

### 1.1 Infrastructure as Code (Terraform + Ansible)
**Status:** In Progress  
**Timeline:** 1-2 weeks  
**Impact:** ⭐⭐⭐⭐⭐

**Goal:** Codify all LXC containers so `git push` → Terraform provisions → Ansible configures.

**Deliverables:**
- [x] Terraform provider configuration for Proxmox
- [x] Terraform modules for each LXC type (core, apps, media, monitoring)
- [x] Ansible inventory from Terraform output
- [x] Ansible playbooks for each service (common, docker roles)
- [ ] CI/CD pipeline for automated deployment
- [ ] Test deployment on Proxmox host

**Directory Structure:**
```
infrastructure/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── modules/
│       ├── lxc-core/
│       ├── lxc-apps/
│       └── lxc-media/
├── ansible/
│   ├── inventory/
│   │   └── hosts.yml
│   ├── playbooks/
│   │   ├── traefik.yml
│   │   ├── postgresql.yml
│   │   └── ...
│   └── roles/
│       ├── common/
│       ├── docker/
│       └── ...
└── secrets/
    └── .sops.yaml
```

### 1.2 Secrets Management (SOPS + Age)
**Status:** In Progress  
**Timeline:** 2 days  
**Impact:** ⭐⭐⭐⭐⭐

**Goal:** Encrypt all secrets in Git using SOPS with Age encryption.

**Deliverables:**
- [ ] Generate Age keypair (run: `age-keygen -o ~/.config/sops/age/keys.txt`)
- [x] Create `.sops.yaml` configuration
- [x] Create secrets template (terraform.yaml.example)
- [ ] Encrypt existing secrets (PostgreSQL, Redis, etc.)
- [ ] Integrate with Ansible (sops-decrypt during playbook runs)
- [ ] Document key backup procedure

### 1.3 K3s Cluster with GitOps (Future)
**Status:** Planning  
**Timeline:** 1-2 months  
**Impact:** ⭐⭐⭐⭐⭐

**Goal:** Production-grade Kubernetes with GitOps for declarative deployments.

**Deliverables:**
- [ ] K3s cluster (single node initially, expand to 3 for HA)
- [ ] ArgoCD or FluxCD for GitOps
- [ ] Migrate stateless services from LXC to K8s
- [ ] Keep stateful services (PostgreSQL, Immich) on LXC

---

## Priority 2: Security Hardening

### 2.1 Authentik (SSO)
**Status:** Not Started  
**LXC ID:** 112  
**IP:** 192.168.1.125  
**URL:** `auth.harmeetrai.com`

**Deliverables:**
- [ ] Deploy Authentik LXC
- [ ] Configure Traefik forward auth middleware
- [ ] Set up OIDC providers for Grafana, Immich, n8n
- [ ] Enable MFA (TOTP/WebAuthn)
- [ ] Document user onboarding process

### 2.2 CrowdSec (Intrusion Detection)
**Status:** Not Started  
**LXC ID:** 113  
**IP:** 192.168.1.127

**Deliverables:**
- [ ] Deploy CrowdSec LXC
- [ ] Install Traefik bouncer
- [ ] Configure log acquisition from Traefik
- [ ] Set up Slack/Discord alerts for bans

### 2.3 Tailscale (VPN)
**Status:** Not Started  
**Timeline:** 30 minutes

**Deliverables:**
- [ ] Install on Proxmox host
- [ ] Advertise homelab subnet (192.168.1.0/24)
- [ ] Install on personal devices
- [ ] Test remote access

---

## Priority 3: Local AI Stack

### 3.1 Ollama + Open WebUI
**Status:** Not Started  
**LXC ID:** 130 (Ollama), 131 (Open WebUI)  
**Hardware Required:** GPU (RTX 3090 recommended)

**Deliverables:**
- [ ] GPU passthrough to LXC (NVIDIA drivers on host)
- [ ] Deploy Ollama with GPU acceleration
- [ ] Deploy Open WebUI
- [ ] Configure Traefik route (`ai.harmeetrai.com`)
- [ ] Pull initial models (llama3.2, mistral, codellama)

---

## Priority 4: Daily-Use Applications

| App | Status | LXC ID | IP | URL |
|-----|--------|--------|-----|-----|
| Homepage | Not Started | 129 | 192.168.1.140 | `home.harmeetrai.com` |
| Uptime Kuma | Not Started | 140 | 192.168.1.141 | `status.harmeetrai.com` |
| Vikunja | Not Started | 122 | 192.168.1.132 | `tasks.harmeetrai.com` |
| Linkwarden | Not Started | 123 | 192.168.1.133 | `bookmarks.harmeetrai.com` |
| Actual Budget | Not Started | 124 | 192.168.1.134 | `budget.harmeetrai.com` |
| Miniflux | Not Started | 126 | 192.168.1.136 | `rss.harmeetrai.com` |
| Radicale | Not Started | 128 | 192.168.1.138 | `cal.harmeetrai.com` |
| Paperless-ngx | Not Started | 135 | 192.168.1.145 | `docs.harmeetrai.com` |

---

## Priority 5: Complete Media Stack

| Service | Status | LXC ID | IP | URL |
|---------|--------|--------|-----|-----|
| Jellyfin | Not Started | 110 | 192.168.1.110 | `jellyfin.harmeetrai.com` |
| Sonarr | Not Started | 111 | 192.168.1.111 | `sonarr.harmeetrai.com` |
| Radarr | Not Started | 112 | 192.168.1.112 | `radarr.harmeetrai.com` |
| Prowlarr | Not Started | 113 | 192.168.1.113 | `prowlarr.harmeetrai.com` |
| qBittorrent | Not Started | 114 | 192.168.1.114 | `qbit.harmeetrai.com` |
| Overseerr | Not Started | 115 | 192.168.1.115 | `requests.harmeetrai.com` |

---

## Priority 6: Advanced Monitoring

| Component | Status | LXC ID | IP | Purpose |
|-----------|--------|--------|-----|---------|
| Loki | Not Started | 141 | 192.168.1.151 | Log aggregation |
| ntfy | Not Started | 142 | 192.168.1.152 | Push notifications |
| LibreNMS | Not Started | 143 | 192.168.1.153 | Network monitoring |

---

## Implementation Phases

### Phase 1: Foundation (Week 1-2) - CURRENT
- [x] Create implementation plan
- [ ] Deploy Homepage dashboard
- [ ] Set up Tailscale VPN
- [ ] Install Authentik SSO
- [ ] Deploy Uptime Kuma
- [ ] Initialize Terraform configuration
- [ ] Set up SOPS secrets management

### Phase 2: Security & IaC (Week 3-4)
- [ ] Complete Terraform modules for all LXCs
- [ ] Create Ansible playbooks for services
- [ ] Deploy CrowdSec intrusion detection
- [ ] Harden PostgreSQL configuration
- [ ] Document disaster recovery procedure

### Phase 3: Daily-Use Apps (Week 5-6)
- [ ] Deploy Vikunja (tasks)
- [ ] Deploy Linkwarden (bookmarks)
- [ ] Deploy Actual Budget (finance)
- [ ] Deploy Miniflux (RSS)
- [ ] Deploy Radicale (calendar/contacts)

### Phase 4: Media Stack (Week 7-8)
- [ ] Deploy Jellyfin
- [ ] Deploy Sonarr + Radarr + Prowlarr
- [ ] Deploy qBittorrent
- [ ] Configure media automations in n8n

### Phase 5: AI & Advanced (Week 9-12)
- [ ] GPU setup and passthrough
- [ ] Deploy Ollama + Open WebUI
- [ ] Deploy Loki + ntfy for advanced monitoring
- [ ] Complete Spotify Library System
- [ ] Evaluate K3s migration

---

## Quick Reference: LXC ID Allocation

| Range | Category | Allocated |
|-------|----------|-----------|
| 100-109 | Core Infrastructure | 104-109 used |
| 110-119 | Media | 110-116 planned |
| 120-129 | Apps | 122-129 planned |
| 130-139 | Dev/AI | 130-131 planned |
| 140-149 | Monitoring | 140-143 planned |

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Services hosted | 8 | 25+ |
| Automated deployments | 0% | 100% |
| SSO coverage | 0% | 100% |
| Secrets in Git (encrypted) | 0% | 100% |
| Uptime | Unknown | 99.9% |
| Recovery time (RTO) | Unknown | < 30 min |

---

## Resources

- [Proxmox Helper Scripts](https://github.com/community-scripts/ProxmoxVE)
- [Terraform Proxmox Provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
- [SOPS Documentation](https://github.com/getsops/sops)
- [Authentik Documentation](https://goauthentik.io/docs/)
