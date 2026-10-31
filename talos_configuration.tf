resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

locals {
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
  config_patches     = concat(local.machine_config_patches[each.value.name], var.talos_control_plane_extra_config_patches, local.tailscale_config_patch != null ? [local.tailscale_config_patch] : [])
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
  config_patches     = concat(local.machine_config_patches[each.value.name], var.talos_worker_extra_config_patches)
  docs               = false
  examples           = false
}
