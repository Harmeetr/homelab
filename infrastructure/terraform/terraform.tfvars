# Terraform Variables - Example Configuration
# Copy this to terraform.tfvars and fill in your values
# WARNING: Do not commit terraform.tfvars to Git - use SOPS for secrets

# =============================================================================
# Proxmox Connection (use environment variables or SOPS for secrets)
# =============================================================================

proxmox_api_url      = "https://192.168.1.77:8006/api2/json"
proxmox_tls_insecure = true
proxmox_node         = "pve"
proxmox_api_token_id     = "terraform@pve!terraform-token"
proxmox_api_token_secret = "20f8829b-5b55-434d-af60-a468c6ff2e57" 
# For API token authentication, set these via environment variables:
# export TF_VAR_proxmox_api_token_id="terraform@pve!terraform-token"
# export TF_VAR_proxmox_api_token_secret="your-secret-here"

# =============================================================================
# Network Configuration
# =============================================================================

network_gateway = "192.168.1.1"
network_cidr    = "/24"
network_bridge  = "vmbr0"
dns_servers     = "192.168.1.1"

# =============================================================================
# Storage Configuration
# =============================================================================

storage_fast     = "tesla"    # NVMe storage for LXC rootfs
storage_bulk     = "apollo"   # RAID storage for data
template_storage = "local"

# =============================================================================
# Default LXC Settings
# =============================================================================

default_template  = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
default_cores     = 2
default_memory    = 2048
default_swap      = 512
default_disk_size = "8G"

# =============================================================================
# SSH Public Keys (for LXC access)
# =============================================================================

ssh_public_keys = <<-EOT
ssh-ed25519 AAAA... user@workstation
EOT
