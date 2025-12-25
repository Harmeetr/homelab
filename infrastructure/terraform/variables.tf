# Terraform Variables
# These define the configuration for Proxmox and LXC containers

# =============================================================================
# Proxmox Connection Variables
# =============================================================================

variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g., https://192.168.1.10:8006/api2/json)"
  type        = string
  default     = "https://192.168.1.10:8006/api2/json"
}

variable "proxmox_api_token_id" {
  description = "Proxmox API Token ID (e.g., terraform@pve!terraform-token)"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification (for self-signed certs)"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "network_gateway" {
  description = "Default gateway for LXC containers"
  type        = string
  default     = "192.168.1.1"
}

variable "network_cidr" {
  description = "Network CIDR suffix"
  type        = string
  default     = "/24"
}

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "dns_servers" {
  description = "DNS servers for LXC containers"
  type        = string
  default     = "192.168.1.1"
}

# =============================================================================
# Storage Configuration
# =============================================================================

variable "storage_fast" {
  description = "Fast storage pool (NVMe) for LXC rootfs"
  type        = string
  default     = "tesla"
}

variable "storage_bulk" {
  description = "Bulk storage pool (RAID) for data"
  type        = string
  default     = "apollo"
}

variable "template_storage" {
  description = "Storage for LXC templates"
  type        = string
  default     = "local"
}

# =============================================================================
# Default LXC Settings
# =============================================================================

variable "default_template" {
  description = "Default LXC template"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
}

variable "default_cores" {
  description = "Default CPU cores for LXC"
  type        = number
  default     = 2
}

variable "default_memory" {
  description = "Default memory (MB) for LXC"
  type        = number
  default     = 2048
}

variable "default_swap" {
  description = "Default swap (MB) for LXC"
  type        = number
  default     = 512
}

variable "default_disk_size" {
  description = "Default root disk size (GB)"
  type        = string
  default     = "8G"
}

# =============================================================================
# SSH Configuration
# =============================================================================

variable "ssh_public_keys" {
  description = "SSH public keys for LXC access"
  type        = string
  default     = ""
}

# =============================================================================
# LXC Container Definitions
# =============================================================================

variable "lxc_containers" {
  description = "Map of LXC containers to create"
  type = map(object({
    vmid        = number
    hostname    = string
    ip_address  = string
    cores       = optional(number)
    memory      = optional(number)
    swap        = optional(number)
    disk_size   = optional(string)
    template    = optional(string)
    unprivileged = optional(bool, true)
    start       = optional(bool, true)
    onboot      = optional(bool, true)
    tags        = optional(list(string), [])
    features    = optional(object({
      nesting = optional(bool, true)
      fuse    = optional(bool, false)
      keyctl  = optional(bool, false)
    }), {})
    mountpoints = optional(list(object({
      key     = string
      slot    = number
      storage = string
      volume  = string
      mp      = string
      size    = optional(string)
    })), [])
  }))
  default = {}
}
