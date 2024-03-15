resource "talos_machine_secrets" "this" {}

locals {
  cluster_endpoint = "https://${local.control_plane_ips[0]}:6443"
  cluster_config_patches = [
    templatefile("${path.module}/patches/cluster-patch.yaml.tmpl", {
      allow_scheduling_on_control_planes = var.worker_count <= 0
    })
  ]
}

data "talos_machine_configuration" "controlplane" {
  count            = var.control_plane_count
  talos_version    = var.talos_version
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = concat(
    local.cluster_config_patches,
    [
      templatefile("${path.module}/patches/machine-patch.yaml.tmpl", {
      })
    ]
  )
  docs     = false
  examples = false
}

data "talos_machine_configuration" "worker" {
  count            = var.worker_count
  talos_version    = var.talos_version
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = concat(
    local.cluster_config_patches,
    [
      templatefile("${path.module}/patches/machine-patch.yaml.tmpl", {
      })
    ]
  )
  docs     = false
  examples = false
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = [
    for controlplane_ip in local.control_plane_ips : controlplane_ip
  ]
}
