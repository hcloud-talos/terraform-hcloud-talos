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

  cluster_api_host_public_explicit  = var.cluster_api_host != null ? trimspace(var.cluster_api_host) : null
  cluster_api_host_private_explicit = var.cluster_api_host_private != null ? trimspace(var.cluster_api_host_private) : null

  default_cluster_api_host_private = "kube.${var.cluster_domain}"

  # Internal hostname for the API endpoint when using the alias IP.
  # Defaults to kube.[cluster_domain], but can be overridden to a workstation/VPN-resolvable name.
  cluster_api_host_private_internal = local.cluster_api_host_private_explicit != null ? local.cluster_api_host_private_explicit : local.default_cluster_api_host_private
  cluster_api_host_public           = local.cluster_api_host_public_explicit != null ? local.cluster_api_host_public_explicit : local.best_public_ipv4

  # Use the best option available for the cluster endpoint
  # cluster_api_host_private (if set) > alias IP (internal hostname) > cluster_api_host > floating IP > first private IP
  cluster_endpoint_internal = (
    local.cluster_api_host_private_explicit != null ? local.cluster_api_host_private_explicit :
    var.enable_alias_ip ? local.cluster_api_host_private_internal :
    local.cluster_api_host_public_explicit != null ? local.cluster_api_host_public_explicit :
    var.enable_floating_ip ? data.hcloud_floating_ip.control_plane_ipv4[0].ip_address :
    local.control_plane_private_ipv4_list[0]
  )
  cluster_endpoint_url_internal = "https://${local.cluster_endpoint_internal}:${local.api_port_k8s}"

  // ************
  cert_SANs = distinct(
    concat(
      local.control_plane_public_ipv4_list,
      local.control_plane_public_ipv6_list,
      local.control_plane_private_ipv4_list,
      compact([
        local.default_cluster_api_host_private,
        local.cluster_api_host_private_internal,
        local.cluster_api_host_public,
        var.enable_alias_ip ? local.control_plane_private_vip_ipv4 : null,
        var.enable_floating_ip ? data.hcloud_floating_ip.control_plane_ipv4[0].ip_address : null,
      ])
    )
  )

  extra_host_entries = var.enable_alias_ip ? [
    {
      ip = local.control_plane_private_vip_ipv4
      aliases = distinct(compact([
        local.default_cluster_api_host_private,
        local.cluster_api_host_private_internal,
      ]))
    }
  ] : []

  tailscale_config_patch = var.tailscale.enabled ? yamlencode({
    apiVersion = "v1alpha1"
    kind       = "ExtensionServiceConfig"
    name       = "tailscale"
    environment = [
      "TS_AUTHKEY=${var.tailscale.auth_key}",
    ]
  }) : null

}

data "talos_machine_configuration" "control_plane" {
  for_each           = { for control_plane in local.control_planes : control_plane.name => control_plane }
  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = concat([yamlencode(local.controlplane_yaml[each.value.name])], var.talos_control_plane_extra_config_patches, local.tailscale_config_patch != null ? [local.tailscale_config_patch] : [])
  docs               = false
  examples           = false
}

data "talos_machine_configuration" "worker" {
  for_each           = { for worker in local.workers : worker.name => worker }
  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = concat([yamlencode(local.worker_yaml[each.value.name])], var.talos_worker_extra_config_patches)
  docs               = false
  examples           = false
}

resource "talos_machine_bootstrap" "this" {
  count                = 1
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
    var.talosconfig_endpoints_mode == "private_ip" ? (
      # Use private IPs in talosconfig
      local.control_plane_private_ipv4_list
    ) :

    var.talosconfig_endpoints_mode == "public_ip" ? (
      # Use public IPs in talosconfig
      local.control_plane_public_ipv4_list
    ) : []
  )
}

resource "talos_cluster_kubeconfig" "this" {
  count                = 1
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.control_plane_public_ipv4_list[0]
  depends_on = [
    talos_machine_bootstrap.this
  ]
}

locals {
  kubeconfig_host = (
    var.kubeconfig_endpoint_mode == "private_ip" ? local.best_private_ipv4 :
    var.kubeconfig_endpoint_mode == "public_ip" ? local.best_public_ipv4 :
    var.kubeconfig_endpoint_mode == "public_endpoint" ? local.cluster_api_host_public_explicit :
    var.kubeconfig_endpoint_mode == "private_endpoint" ? local.cluster_api_host_private_explicit :
    "unknown"
  )
  kubeconfig = replace(
    can(talos_cluster_kubeconfig.this[0].kubeconfig_raw) ? talos_cluster_kubeconfig.this[0].kubeconfig_raw : "",
    local.cluster_endpoint_url_internal, "https://${local.kubeconfig_host}:${local.api_port_k8s}"
  )

  kubeconfig_data = {
    host                   = "https://${local.kubeconfig_host}:${local.api_port_k8s}"
    cluster_name           = var.cluster_name
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.ca_certificate)
    client_certificate     = base64decode(talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.this[0].kubernetes_client_configuration.client_key)
  }
}
