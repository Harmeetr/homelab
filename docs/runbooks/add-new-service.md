# Adding New Services Runbook

## Overview

This runbook covers how to add a new service to the homelab infrastructure.

---

## Pre-flight Checklist

- [ ] Service has a Proxmox Helper Script available (check [helper-scripts.com](https://helper-scripts.com))
- [ ] Determine resource requirements (RAM, disk)
- [ ] Determine storage needs (NVMe vs RAID)
- [ ] Choose LXC ID (follow naming convention)
- [ ] Plan subdomain if external access needed

---

## LXC ID Convention

| Range | Category |
|-------|----------|
| 100-109 | Core infrastructure |
| 110-119 | Media services |
| 120-129 | Apps/Productivity |
| 130-139 | Development/AI |
| 140-149 | Monitoring/Logging |

---

## Step-by-Step Process

### 1. Run Helper Script

```bash
# SSH to Proxmox host
# Run the helper script for your service
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/ct/SERVICE_NAME.sh)"
```

Follow the prompts:
- Choose "Advanced" for custom configuration
- Set LXC ID according to convention
- Set hostname (e.g., `service-name`)
- Allocate appropriate RAM and disk

### 2. Configure Storage Mounts (if needed)

```bash
# Add bind mount to LXC config
pct set <LXC_ID> -mp0 /host/path,mp=/container/path

# Example: Add media access to new service
pct set 130 -mp0 /Apollo/Media,mp=/media
```

### 3. Configure PostgreSQL Database (if needed)

```bash
# SSH into PostgreSQL LXC
pct enter 101

# Create database and user
sudo -u postgres psql

CREATE DATABASE newservice;
CREATE USER newservice WITH ENCRYPTED PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE newservice TO newservice;
\q

exit
```

### 4. Add Traefik Route

Edit Traefik dynamic configuration to add the new service:

```yaml
# /path/to/traefik/dynamic.yml
http:
  routers:
    newservice:
      rule: "Host(`newservice.harmeetrai.com`)"
      service: newservice
      entryPoints:
        - websecure
      tls: {}

  services:
    newservice:
      loadBalancer:
        servers:
          - url: "http://<LXC_IP>:<PORT>"
```

### 5. Add Cloudflare DNS Record

1. Log into Cloudflare Dashboard
2. Go to harmeetrai.com DNS settings
3. Add CNAME record:
   - Name: `newservice`
   - Target: Your tunnel hostname
   - Proxy: Yes (orange cloud)

### 6. Add to Prometheus Monitoring (if applicable)

```yaml
# /path/to/prometheus/prometheus.yml
scrape_configs:
  - job_name: 'newservice'
    static_configs:
      - targets: ['<LXC_IP>:<METRICS_PORT>']
```

### 7. Configure Backup

Add the service's data directory to the Restic backup script:

```bash
# Add to backup script
restic backup /Apollo/NewService/
```

### 8. Update Documentation

1. Add to LXC Inventory in Obsidian note
2. Add to services table in GitHub README
3. Update architecture diagram if significant

---

## Post-Installation Checklist

- [ ] Service accessible via LXC IP
- [ ] Service accessible via subdomain
- [ ] Prometheus scraping metrics (if applicable)
- [ ] Backup configured
- [ ] Documentation updated
