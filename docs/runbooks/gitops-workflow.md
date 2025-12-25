# GitOps Workflow Setup

**Runner LXC:** 130 (Claude Agent)  
**Runner IP:** 192.168.1.126  
**Managed Services:** Traefik, Homepage

## Overview

This runbook covers setting up the GitOps workflow for automatic config deployment.

```
GitHub (push) → GitHub Actions → Self-hosted Runner → Ansible → LXCs
```

---

## Prerequisites

- SSH access to Claude Agent LXC (130)
- Network connectivity from LXC 130 to managed LXCs

## Security Model (Public Repo)

This repo is public for portfolio/resume purposes. The workflow is safe because:

1. **Trigger restrictions**: Only runs on `push` to `main` and `workflow_dispatch`
2. **No PR triggers**: Fork PRs cannot trigger the workflow
3. **Owner check**: `if: github.repository_owner == 'harmeetrai'` prevents forks from running it
4. **Write access required**: Only repo owner can push to `main` or trigger manual runs

---

## Step 1: Install Dependencies on Runner LXC

```bash
ssh root@192.168.1.126

apt update && apt install -y \
  ansible \
  python3-pip \
  git \
  curl \
  jq

pip3 install docker
```

---

## Step 2: Generate SSH Keys

```bash
ssh-keygen -t ed25519 -C "github-runner" -f ~/.ssh/id_ed25519 -N ""

cat ~/.ssh/id_ed25519.pub
```

Copy the public key output.

---

## Step 3: Distribute SSH Keys to Managed LXCs

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.1.116
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.1.140

ssh -o BatchMode=yes root@192.168.1.116 "hostname"
ssh -o BatchMode=yes root@192.168.1.140 "hostname"
```

Both commands should return the hostname without prompting for password.

---

## Step 4: Install GitHub Actions Runner

### 4.1 Get Registration Token

1. Go to your GitHub repository
2. Navigate to **Settings → Actions → Runners**
3. Click **New self-hosted runner**
4. Copy the token from the configuration command

### 4.2 Download and Configure Runner

```bash
mkdir -p ~/actions-runner && cd ~/actions-runner

RUNNER_VERSION="2.321.0"
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
  https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

./config.sh --url https://github.com/YOUR_USERNAME/homelab \
  --token YOUR_REGISTRATION_TOKEN \
  --labels homelab,self-hosted \
  --name homelab-runner \
  --work _work \
  --unattended
```

Replace:
- `YOUR_USERNAME` with your GitHub username
- `YOUR_REGISTRATION_TOKEN` with the token from step 4.1

### 4.3 Install and Start Service

```bash
sudo ./svc.sh install
sudo ./svc.sh start
sudo ./svc.sh status
```

---

## Step 5: Verify Runner Registration

1. Go to **Settings → Actions → Runners** in your GitHub repository
2. You should see `homelab-runner` with status **Idle**

---

## Step 6: Test Deployment

### Manual Trigger

1. Go to **Actions** tab in GitHub
2. Select **Deploy Homelab Configs** workflow
3. Click **Run workflow**
4. Select target: `all`, `traefik`, or `homepage`

### Push Trigger

1. Edit any file in `configs/` directory via GitHub web UI
2. Commit to `main` branch
3. Watch the Actions tab for the workflow run

---

## Managed Services

| Service | Config Source | Destination | Reload Method |
|---------|--------------|-------------|---------------|
| Traefik | `configs/traefik/` | `/etc/traefik/conf.d/` | Auto (file provider) |
| Homepage | `configs/homepage/` | `/opt/homepage/config/` | Docker restart |

---

## Adding New Services

1. Create config directory: `configs/<service>/`
2. Add config files to the directory
3. Update `infrastructure/ansible/inventory/hosts.yml`:

```yaml
config_managed:
  hosts:
    newservice:
      ansible_host: 192.168.1.XXX
      lxc_id: XXX
      config_src: newservice
      config_dest: /path/to/config
```

4. Add handler in `infrastructure/ansible/playbooks/deploy-configs.yml`:

```yaml
handlers:
  - name: reload newservice
    ansible.builtin.command:
      cmd: systemctl restart newservice
    listen: "reload newservice"
```

5. Copy SSH key to new LXC:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.1.XXX
```

---

## Rollback

If a config breaks something:

```bash
git revert HEAD
git push origin main
```

The workflow will automatically deploy the previous config.

---

## Troubleshooting

### Runner Not Picking Up Jobs

```bash
ssh root@192.168.1.126
cd ~/actions-runner
sudo ./svc.sh status

sudo ./svc.sh stop
sudo ./svc.sh start
```

### Ansible Connection Failures

```bash
ssh -o BatchMode=yes root@192.168.1.116 "hostname"

ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.1.116
```

### Check Runner Logs

```bash
journalctl -u actions.runner.YOUR_USERNAME-homelab.homelab-runner -f
```

---

## SOPS Integration (Future)

When adding secrets:

1. Install SOPS and age on runner:

```bash
apt install -y age

wget -O /usr/local/bin/sops \
  https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
chmod +x /usr/local/bin/sops
```

2. Copy age private key:

```bash
mkdir -p ~/.config/sops/age
echo 'YOUR_AGE_PRIVATE_KEY' > ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

3. Add `SOPS_AGE_KEY` to GitHub Secrets (for backup/cloud runners)

4. Install Ansible SOPS collection:

```bash
ansible-galaxy collection install community.sops
```
