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

    helm = {
      source  = "hashicorp/helm"
      version = ">=2.12.1"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }

    time = {
      source  = "hashicorp/time"
      version = ">=0.11.1"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "helm" {
  kubernetes {
    host                   = length(local.control_plane_public_ipv4_list) > 0 ? "${local.control_plane_public_ipv4_list[0]}:${local.cluster_api_port_k8s}" : ""
    client_certificate     = base64decode(length(data.talos_cluster_kubeconfig.this) > 0 ? data.talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.client_certificate : "")
    client_key             = base64decode(length(data.talos_cluster_kubeconfig.this) > 0 ? data.talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.client_key : "")
    cluster_ca_certificate = base64decode(length(data.talos_cluster_kubeconfig.this) > 0 ? data.talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.ca_certificate : "")
  }
}

provider "kubectl" {
  host                   = length(local.control_plane_public_ipv4_list) > 0 ? "${local.control_plane_public_ipv4_list[0]}:${local.cluster_api_port_k8s}" : ""
  client_certificate     = base64decode(length(data.talos_cluster_kubeconfig.this) > 0 ? data.talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.client_certificate : "")
  client_key             = base64decode(length(data.talos_cluster_kubeconfig.this) > 0 ? data.talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.client_key : "")
  cluster_ca_certificate = base64decode(length(data.talos_cluster_kubeconfig.this) > 0 ? data.talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.ca_certificate : "")
  load_config_file       = false
  apply_retry_count      = 3
}