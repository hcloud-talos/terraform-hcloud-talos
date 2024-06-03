resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

locals {
  api_port_k8s        = 6443
  api_port_kube_prism = 7445

  best_public_ipv4 = (
    var.enable_floating_ip ?
    # Use floating IP
    data.hcloud_floating_ip.control_plane_ipv4[0].ip_address :
    # Use first public IP
    can(local.control_plane_public_ipv4_list[0]) ? local.control_plane_public_ipv4_list[0] : "unknown"
  )

  best_private_ipv4 = (
    var.enable_alias_ip ?
    # Use alias IP
    local.control_plane_private_vip_ipv4 :
    # Use first private IP
    local.control_plane_private_ipv4_list[0]
  )

  cluster_api_host_private = "kube.${var.cluster_domain}"
  cluster_api_host_public  = var.cluster_api_host != null ? var.cluster_api_host : local.best_public_ipv4

  # Use the best option available for the cluster endpoint
  # cluster_api_host_private (alias IP) > cluster_api_host > floating IP > first private IP
  cluster_endpoint_internal = var.enable_alias_ip ? local.cluster_api_host_private : (
    var.cluster_api_host != null ? var.cluster_api_host : (
      var.enable_floating_ip ? data.hcloud_floating_ip.control_plane_ipv4[0].ip_address :
      local.control_plane_private_ipv4_list[0]
    )
  )
  cluster_endpoint_url_internal = "https://${local.cluster_endpoint_internal}:${local.api_port_k8s}"

  // ************
  cert_SANs = distinct(
    concat(
      local.control_plane_public_ipv4_list,
      local.control_plane_public_ipv6_list,
      local.control_plane_private_ipv4_list,
      compact([
        local.cluster_api_host_private,
        local.cluster_api_host_public,
        var.enable_alias_ip ? local.control_plane_private_vip_ipv4 : null,
        var.enable_floating_ip ? data.hcloud_floating_ip.control_plane_ipv4[0].ip_address : null,
      ])
    )
  )

  extra_host_entries = var.enable_alias_ip ? [
    {
      ip = local.control_plane_private_vip_ipv4
      aliases = [
        local.cluster_api_host_private
      ]
    }
  ] : []
}

data "talos_machine_configuration" "control_plane" {
  // enable although we have no control planes, to be able to debug the output
  for_each           = { for control_plane in local.control_planes : control_plane.name => control_plane }
  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = [yamlencode(local.controlplane_yaml[each.value.name])]
  docs               = false
  examples           = false
}

data "talos_machine_configuration" "worker" {
  // enable although we have no worker, to be able to debug the output
  for_each           = { for worker in local.workers : worker.name => worker }
  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = [yamlencode(local.worker_yaml[each.value.name])]
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
  endpoints = compact(
    var.output_mode_config_cluster_endpoint == "private_ip" ? (
      # Use private IP in talosconfig
      var.enable_alias_ip ?
      # Use alias IP in talosconfig
      [local.control_plane_private_vip_ipv4] :
      # Use private IPs in talosconfig
      local.control_plane_private_ipv4_list
    ) :

    var.output_mode_config_cluster_endpoint == "public_ip" ? (
      # Use public IP in talosconfig
      var.enable_floating_ip ?
      # Use floating IP in talosconfig
      [data.hcloud_floating_ip.control_plane_ipv4[0].ip_address] :
      # Use public IPs in talosconfig
      can(local.control_plane_public_ipv4_list) ? local.control_plane_public_ipv4_list : []
    ) :

    var.output_mode_config_cluster_endpoint == "cluster_endpoint" ? (
      # Use cluster endpoint in talosconfig
      [local.cluster_api_host_public]
    ) : []
  )
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
  kubeconfig_host = (
    var.output_mode_config_cluster_endpoint == "private_ip" ? local.best_private_ipv4 :
    var.output_mode_config_cluster_endpoint == "public_ip" ? local.best_public_ipv4 :
    var.output_mode_config_cluster_endpoint == "cluster_endpoint" ? local.cluster_api_host_public :
    "unknown"
  )
  kubeconfig = replace(
    can(data.talos_cluster_kubeconfig.this[0].kubeconfig_raw) ? data.talos_cluster_kubeconfig.this[0].kubeconfig_raw : "",
    local.cluster_endpoint_url_internal, "https://${local.kubeconfig_host}:${local.api_port_k8s}"
  )

  kubeconfig_data = {
    host                   = "https://${local.best_public_ipv4}:${local.api_port_k8s}"
    cluster_name           = var.cluster_name
    cluster_ca_certificate = var.control_plane_count > 0 ? base64decode(data.talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.ca_certificate) : tls_self_signed_cert.dummy_ca[0].cert_pem
    client_certificate     = var.control_plane_count > 0 ? base64decode(data.talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.client_certificate) : tls_locally_signed_cert.dummy_issuer[0].cert_pem
    client_key             = var.control_plane_count > 0 ? base64decode(data.talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.client_key) : tls_private_key.dummy_issuer[0].private_key_pem
  }
}
