terraform {
  required_version = "1.7.5"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">=1.45.0"
    }

    talos = {
      source  = "siderolabs/talos"
      version = ">=0.4.0"
    }

    http = {
      source  = "hashicorp/http"
      version = ">=3.4.2"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}