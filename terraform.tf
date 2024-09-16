terraform {
  required_version = ">=1.8.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.48.1"
    }

    talos = {
      source  = "siderolabs/talos"
      version = ">=0.5.0"
    }

    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.4"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.15.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">=1.14.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.6"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "helm" {
  kubernetes {
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
