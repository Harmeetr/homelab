# Terraform Providers Configuration
# Proxmox VE Provider for LXC container management

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "~> 2.9"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.0"
    }
  }

  # Optional: Remote state storage
  # backend "s3" {
  #   bucket         = "homelab-terraform-state"
  #   key            = "terraform.tfstate"
  #   region         = "us-west-2"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

# Proxmox Provider Configuration
# Credentials should be provided via environment variables:
#   PM_API_URL, PM_API_TOKEN_ID, PM_API_TOKEN_SECRET
# Or via SOPS-encrypted secrets file

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = var.proxmox_tls_insecure

  pm_log_enable = false
  pm_log_file   = "terraform-plugin-proxmox.log"
  pm_debug      = false
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }
}

# SOPS Provider for encrypted secrets
provider "sops" {}
