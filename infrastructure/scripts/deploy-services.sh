#!/bin/bash
set -euo pipefail

GATEWAY="192.168.1.1"
BRIDGE="vmbr0"
SSH_KEY="${SSH_KEY:-}"

# CT IDs and IPs from inventory.md
declare -A SERVICES=(
  ["uptimekuma"]="140:192.168.1.150:1:1024:4:monitoring"
  ["authentik"]="112:192.168.1.125:2:4096:8:security"
  ["crowdsec"]="141:192.168.1.151:1:512:4:security"
  ["ollama"]="131:192.168.1.141:4:8192:32:ai"
  ["vikunja"]="122:192.168.1.132:1:1024:4:productivity"
  ["linkwarden"]="123:192.168.1.133:2:2048:8:productivity"
  ["actualbudget"]="124:192.168.1.134:1:1024:4:productivity"
  ["miniflux"]="126:192.168.1.136:1:512:4:productivity"
)

log() { echo "[$(date '+%H:%M:%S')] $1"; }

deploy_service() {
  local app="$1"
  local config="${SERVICES[$app]}"
  
  IFS=':' read -r ctid ip cpu ram disk tags <<< "$config"
  
  log "Deploying $app (CT $ctid @ $ip)..."
  
  var_ctid="$ctid" \
  var_hostname="$app" \
  var_cpu="$cpu" \
  var_ram="$ram" \
  var_disk="$disk" \
  var_net="${ip}/24" \
  var_gateway="$GATEWAY" \
  var_brg="$BRIDGE" \
  var_unprivileged=1 \
  var_ssh=yes \
  var_tags="$tags,homelab" \
  ${SSH_KEY:+var_ssh_authorized_key="$SSH_KEY"} \
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/${app}.sh)"
  
  if pct list | grep -q "^$ctid "; then
    log "SUCCESS: $app deployed (CT $ctid @ $ip)"
    return 0
  else
    log "FAILED: $app deployment failed"
    return 1
  fi
}

show_status() {
  echo ""
  echo "=== Deployment Plan ==="
  printf "%-15s %-6s %-16s %-4s %-6s %-4s %s\n" "SERVICE" "CT_ID" "IP" "CPU" "RAM" "DISK" "TAGS"
  echo "-----------------------------------------------------------------------"
  for app in "${!SERVICES[@]}"; do
    IFS=':' read -r ctid ip cpu ram disk tags <<< "${SERVICES[$app]}"
    printf "%-15s %-6s %-16s %-4s %-6s %-4s %s\n" "$app" "$ctid" "$ip" "$cpu" "${ram}MB" "${disk}GB" "$tags"
  done
  echo ""
}

case "${1:-}" in
  "all")
    show_status
    read -p "Deploy all services? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      for app in uptimekuma authentik crowdsec vikunja linkwarden actualbudget miniflux; do
        deploy_service "$app" || true
        sleep 5
      done
      log "Batch deployment complete"
    fi
    ;;
  "status")
    show_status
    ;;
  *)
    if [[ -n "${1:-}" ]] && [[ -v "SERVICES[$1]" ]]; then
      deploy_service "$1"
    else
      echo "Usage: $0 {all|status|<service_name>}"
      echo ""
      echo "Available services:"
      for app in "${!SERVICES[@]}"; do echo "  - $app"; done
      echo ""
      echo "Examples:"
      echo "  $0 status      # Show deployment plan"
      echo "  $0 uptimekuma  # Deploy single service"
      echo "  $0 all         # Deploy all services"
    fi
    ;;
esac
