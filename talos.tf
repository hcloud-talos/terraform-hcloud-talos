resource "talos_machine_secrets" "this" {}

locals {
  // https://github.com/kubebn/talos-proxmox-kaas?tab=readme-ov-file#cilium-cni-configuration
  local_api_host              = "api.${var.cluster_domain}"
  cluster_api_host            = var.cluster_api_host != null ? var.cluster_api_host : local.local_api_host
  cluster_api_port_k8s        = 6443
  cluster_api_port_kube_prism = 7445
  #  cluster_api_url_k8s         = "https://${local.cluster_api_host}:${local.cluster_api_port_k8s}"
  cluster_api_url_kube_prism = "https://${local.local_api_host}:${local.cluster_api_port_kube_prism}"
  cluster_endpoint           = local.cluster_api_url_kube_prism
  // ************
  cert_SANs = concat(
    local.control_plane_public_ipv4_list,
    local.control_plane_public_ipv6_list,
    local.control_plane_private_ipv4_list,
    compact([
      local.local_api_host,
      local.cluster_api_host,
      # TODO: not working atm https://github.com/siderolabs/talos/issues/3599
      #      local.control_plane_private_ipv4_vip,
      var.enable_floating_ip ? data.hcloud_floating_ip.control_plane_ipv4[0].ip_address : null,
    ])
  )

  extra_host_entries = [
    {
      ip = "127.0.0.1"
      aliases = [
        local.local_api_host
      ]
    }
  ]
}

data "talos_machine_configuration" "control_plane" {
  // enable although we have no control planes, to be able to debug the output
  count              = var.control_plane_count > 0 ? var.control_plane_count : 1
  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  kubernetes_version = var.kubernetes_version != null ? var.kubernetes_version : null
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = [local.controlplane_yaml[count.index]]
  docs               = false
  examples           = false
}

data "talos_machine_configuration" "worker" {
  // enable although we have no worker, to be able to debug the output
  count              = var.worker_count > 0 ? var.worker_count : 1
  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  kubernetes_version = var.kubernetes_version != null ? var.kubernetes_version : null
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = [local.worker_yaml[count.index]]
  docs               = false
  examples           = false
}

resource "talos_machine_bootstrap" "this" {
  count                = var.control_plane_count > 0 ? 1 : 0
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = local.control_plane_public_ipv4_list[0]
  node                 = local.control_plane_public_ipv4_list[0]
  depends_on = [
    hcloud_server.control_planes
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = [
    for server in hcloud_server.control_planes : server.ipv4_address
  ]
}

data "talos_cluster_kubeconfig" "this" {
  count                = var.control_plane_count > 0 ? 1 : 0
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.control_plane_public_ipv4_list[0]
  depends_on = [
    talos_machine_bootstrap.this
  ]
}

locals {
  kubeconfig_host = var.enable_floating_ip ? data.hcloud_floating_ip.control_plane_ipv4[0].ip_address : (
    can(local.control_plane_public_ipv4_list[0]) ? local.control_plane_public_ipv4_list[0] : "unknown"
  )

  kubeconfig_endpoint = "https://${local.kubeconfig_host}:${local.cluster_api_port_k8s}"

  kubeconfig = replace(
    can(data.talos_cluster_kubeconfig.this[0].kubeconfig_raw) ? data.talos_cluster_kubeconfig.this[0].kubeconfig_raw : "",
    local.cluster_endpoint, local.kubeconfig_endpoint
  )

  kubeconfig_data = {
    host                   = local.kubeconfig_endpoint
    cluster_name           = var.cluster_name
    cluster_ca_certificate = var.control_plane_count > 0 ? base64decode(data.talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.ca_certificate) : tls_self_signed_cert.dummy_ca[0].cert_pem
    client_certificate     = var.control_plane_count > 0 ? base64decode(data.talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.client_certificate) : tls_locally_signed_cert.dummy_issuer[0].cert_pem
    client_key             = var.control_plane_count > 0 ? base64decode(data.talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.client_key) : tls_private_key.dummy_issuer[0].private_key_pem
  }
}

data "http" "talos_health" {
  url      = "${local.kubeconfig_endpoint}/version"
  insecure = true
  retry {
    attempts     = 60
    min_delay_ms = 5000
    max_delay_ms = 5000
  }
  depends_on = [talos_machine_bootstrap.this]
}
