# Deploy Tailscale VPN

**Install Location:** Proxmox Host  
**Purpose:** Secure remote access without port forwarding

## Prerequisites

- Tailscale account (free tier: 100 devices, 3 users)
- Proxmox root access

## Step 1: Install Tailscale on Proxmox Host

```bash
# SSH to Proxmox
ssh root@proxmox.local

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate and advertise subnet
tailscale up --advertise-routes=192.168.1.0/24 --accept-routes

# Follow the URL to authenticate in browser
```

## Step 2: Enable Subnet Routes in Admin Console

1. Go to https://login.tailscale.com/admin/machines
2. Find your Proxmox machine
3. Click the three dots menu → "Edit route settings"
4. Enable the `192.168.1.0/24` subnet route
5. Click "Save"

## Step 3: Install Tailscale on Client Devices

### macOS/Windows/Linux
Download from https://tailscale.com/download

### iOS/Android
Install from App Store / Play Store

### Login with same account

## Step 4: Configure Exit Node (Optional)

```bash
# On Proxmox, enable exit node
tailscale up --advertise-routes=192.168.1.0/24 --advertise-exit-node

# Enable in admin console (same as step 2)
```

## Step 5: Enable MagicDNS (Optional)

1. Go to https://login.tailscale.com/admin/dns
2. Enable MagicDNS
3. Access services via `hostname.tail-scale.ts.net`

## Usage

After setup, access homelab services from anywhere:

```bash
# Direct IP (via subnet routing)
curl http://192.168.1.121:2283  # Immich

# Or via Tailscale IP
curl http://100.x.x.x:2283

# Or via MagicDNS
curl http://proxmox.tail-scale.ts.net
```

## Verification

```bash
# On Proxmox
tailscale status

# Check subnet routing
tailscale status --json | jq '.Self.AllowedIPs'

# From client device, ping homelab IP
ping 192.168.1.121
```

## Troubleshooting

```bash
# Check Tailscale service
systemctl status tailscaled

# View logs
journalctl -u tailscaled -f

# Re-authenticate
tailscale logout && tailscale up --advertise-routes=192.168.1.0/24

# Check firewall
iptables -L -n | grep -i tailscale
```

## Security Notes

- Tailscale uses WireGuard encryption
- No ports need to be opened on router
- Device authorization required for new devices
- Consider enabling key expiry in admin console
