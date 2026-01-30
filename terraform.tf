terraform {
  required_version = ">=1.9.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.60.1"
    }

    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.10.1"
    }

    http = {
      source  = "hashicorp/http"
      version = ">= 3.5.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.1"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.1.3"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.2.1"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "helm" {
  kubernetes = {
    host                   = local.kubeconfig_data.host
    client_certificate     = local.kubeconfig_data.client_certificate
    client_key             = local.kubeconfig_data.client_key
    cluster_ca_certificate = local.kubeconfig_data.cluster_ca_certificate
  }
}

provider "kubectl" {
  host                   = local.kubeconfig_data.host
  client_certificate     = local.kubeconfig_data.client_certificate
  client_key             = local.kubeconfig_data.client_key
  cluster_ca_certificate = local.kubeconfig_data.cluster_ca_certificate
  load_config_file       = false
  apply_retry_count      = 3
}
