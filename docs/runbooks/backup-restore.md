# Backup & Restore Runbook

## Overview

Backups are managed via Restic with Backblaze B2 as the storage backend.

---

## Backup Schedule

| Data | Frequency | Retention |
|------|-----------|-----------|
| PostgreSQL databases | Daily 2am | 30 days |
| LXC configs | Weekly Sunday | 4 weeks |
| Immich photos | Daily 3am | Forever |
| Nextcloud files | Daily 3am | 30 days |

---

## Manual Backup Commands

### PostgreSQL Backup
```bash
# SSH into PostgreSQL LXC
pct enter 101

# Dump all databases
pg_dumpall -U postgres > /tmp/postgres_backup_$(date +%Y%m%d).sql

# Exit and copy to backup staging
exit
pct pull 101 /tmp/postgres_backup_*.sql /Apollo/Backups/local/
```

### Restic Backup to B2
```bash
# Set environment variables
export B2_ACCOUNT_ID="your_account_id"
export B2_ACCOUNT_KEY="your_account_key"
export RESTIC_REPOSITORY="b2:homelab-backups"
export RESTIC_PASSWORD="your_restic_password"

# Backup PostgreSQL dumps
restic backup /Apollo/Backups/local/postgres/

# Backup Immich photos
restic backup /Apollo/Photos/

# Backup Nextcloud data
restic backup /Apollo/Nextcloud/

# Backup configs
restic backup /Apollo/Backups/local/configs/
```

---

## Restore Procedures

### Restore PostgreSQL Database

```bash
# List available snapshots
restic snapshots

# Restore latest PostgreSQL backup
restic restore latest --target /tmp/restore --include postgres/

# SSH into PostgreSQL LXC
pct enter 101

# Restore the database
psql -U postgres < /tmp/restore/postgres_backup_YYYYMMDD.sql
```

### Restore Immich Photos

```bash
# List snapshots
restic snapshots

# Restore to original location
restic restore latest --target /Apollo/Photos/ --include Photos/

# Restart Immich to pick up restored files
pct restart 120
```

### Restore Full LXC from Proxmox Backup

```bash
# List available backups
pvesm list local

# Restore LXC (example: Immich, ID 120)
pct restore 120 /var/lib/vz/dump/vzdump-lxc-120-*.tar.zst
```

---

## Verification

### Check Backup Integrity
```bash
# Verify repository integrity
restic check

# List files in latest snapshot
restic ls latest
```

### Test Restore (Monthly)
1. Restore a random file from each backup set
2. Verify file contents are correct
3. Document test in backup log

---

## Troubleshooting

### Restic: "repository not found"
```bash
# Initialize repository if new
restic init
```

### Restic: "wrong password"
- Verify `RESTIC_PASSWORD` environment variable
- Check password file if using `--password-file`

### B2: "unauthorized"
- Verify B2_ACCOUNT_ID and B2_ACCOUNT_KEY
- Check that B2 bucket exists and key has write access
