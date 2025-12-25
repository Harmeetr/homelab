# Main Terraform Configuration
# Deploys NEW LXC containers only - existing containers are not managed

# =============================================================================
# EXISTING CONTAINERS (Reference Only - NOT managed by Terraform)
# Import these with: terraform import proxmox_lxc.existing["name"] pve/lxc/<vmid>
# =============================================================================

locals {
  existing_containers = {
    traefik     = { vmid = 104, ip = "192.168.1.116" }
    postgresql  = { vmid = 105, ip = "192.168.1.117" }
    redis       = { vmid = 106, ip = "192.168.1.118" }
    cloudflared = { vmid = 107, ip = "192.168.1.120" }
    immich      = { vmid = 108, ip = "192.168.1.121" }
    n8n         = { vmid = 109, ip = "192.168.1.122" }
    prometheus  = { vmid = 110, ip = "192.168.1.123" }
    grafana     = { vmid = 111, ip = "192.168.1.124" }
    homepage    = { vmid = 113, ip = "192.168.1.127" }
    claude      = { vmid = 130, ip = "192.168.1.126" }
  }
}

# =============================================================================
# NEW CONTAINERS (Managed by Terraform)
# Values from Proxmox Helper Scripts: https://github.com/community-scripts/ProxmoxVE
# =============================================================================

locals {
  new_containers = {
    uptime-kuma = {
      vmid         = 140
      hostname     = "uptime-kuma"
      ip_address   = "192.168.1.150"
      cores        = 1
      memory       = 1024
      disk_size    = "4G"
      os_type      = "debian"
      unprivileged = true
      tags         = ["monitoring"]
      port         = 3001
    }
    vikunja = {
      vmid         = 122
      hostname     = "vikunja"
      ip_address   = "192.168.1.132"
      cores        = 1
      memory       = 1024
      disk_size    = "4G"
      os_type      = "debian"
      unprivileged = true
      tags         = ["apps", "productivity"]
      port         = 3456
    }
    linkwarden = {
      vmid         = 123
      hostname     = "linkwarden"
      ip_address   = "192.168.1.133"
      cores        = 2
      memory       = 4096
      disk_size    = "12G"
      os_type      = "ubuntu"
      unprivileged = false
      tags         = ["apps", "productivity"]
      port         = 3000
    }
    actualbudget = {
      vmid         = 124
      hostname     = "actualbudget"
      ip_address   = "192.168.1.134"
      cores        = 2
      memory       = 2048
      disk_size    = "4G"
      os_type      = "debian"
      unprivileged = true
      tags         = ["apps", "finance"]
      port         = 5006
    }
    miniflux = {
      vmid         = 126
      hostname     = "miniflux"
      ip_address   = "192.168.1.136"
      cores        = 2
      memory       = 2048
      disk_size    = "8G"
      os_type      = "debian"
      unprivileged = true
      tags         = ["apps", "media"]
      port         = 8080
    }
  }

  os_templates = {
    debian = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    ubuntu = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  }
}

# =============================================================================
# Create NEW LXC Containers
# =============================================================================

resource "proxmox_lxc" "containers" {
  for_each = local.new_containers

  target_node  = var.proxmox_node
  vmid         = each.value.vmid
  hostname     = each.value.hostname
  ostemplate   = local.os_templates[each.value.os_type]
  unprivileged = each.value.unprivileged
  start        = true
  onboot       = true

  cores  = each.value.cores
  memory = each.value.memory
  swap   = 512

  rootfs {
    storage = var.storage_fast
    size    = each.value.disk_size
  }

  network {
    name   = "eth0"
    bridge = var.network_bridge
    ip     = "${each.value.ip_address}${var.network_cidr}"
    gw     = var.network_gateway
  }

  features {
    nesting = true
    fuse    = false
    keyctl  = each.value.os_type == "ubuntu" ? true : false
  }

  tags = join(";", each.value.tags)

  ssh_public_keys = var.ssh_public_keys

  lifecycle {
    ignore_changes = [rootfs[0].size]
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "new_container_ips" {
  description = "IP addresses of newly created containers"
  value = {
    for name, container in proxmox_lxc.containers :
    name => container.network[0].ip
  }
}

output "new_container_ids" {
  description = "VMIDs of newly created containers"
  value = {
    for name, container in proxmox_lxc.containers :
    name => container.vmid
  }
}

output "service_urls" {
  description = "Service URLs for Traefik configuration"
  value = {
    for name, config in local.new_containers :
    name => "http://${config.ip_address}:${config.port}"
  }
}
