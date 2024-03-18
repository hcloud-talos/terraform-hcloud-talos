resource "talos_machine_secrets" "this" {}

locals {
  // TODO: Possible to make domain and api_domain configurable?
  // https://github.com/kubebn/talos-proxmox-kaas?tab=readme-ov-file#cilium-cni-configuration
  cluster_domain       = "cluster.local"
  cluster_api_host     = "api.${local.cluster_domain}"
  cluster_api_port_k8s = 6443
  #  cluster_api_url_k8s         = "https://${local.cluster_api_host}:${local.cluster_api_port_k8s}"
  cluster_api_port_kube_prism = 7445
  cluster_api_url_kube_prism  = "https://${local.cluster_api_host}:${local.cluster_api_port_kube_prism}"
  // ************
  cert_SANs = concat(
    local.control_plane_public_ipv4_list,
    local.control_plane_public_ipv6_list,
    local.control_plane_private_ipv4_list,
    [local.cluster_api_host]
  )
  extra_host_entries = concat(
    [
      "127.0.0.1:${local.cluster_api_host}"
    ]
  )
}

data "talos_machine_configuration" "control_plane" {
  // enable although we have no control planes to be able to debug the output
  count            = var.control_plane_count > 0 ? var.control_plane_count : 1
  talos_version    = var.talos_version
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_api_url_kube_prism
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = concat(
    [
      templatefile("${path.module}/patches/controlplane.yaml.tpl", {
        allowSchedulingOnControlPlanes = var.worker_count <= 0,
        domain                         = local.cluster_domain
        apiDomain                      = local.cluster_api_host
        certSANs                       = join(",", local.cert_SANs)
        nodeSubnets                    = local.node_ipv4_cidr
        nodeCidrMaskSizeIpv4           = local.node_ipv4_cidr_mask_size
        podSubnets                     = local.pod_ipv4_cidr
        serviceSubnets                 = local.service_ipv4_cidr
        hcloudNetwork                  = hcloud_network.this.id
        hcloudToken                    = var.hcloud_token
        extraHostEntries               = join(",", local.extra_host_entries)
      })
    ]
  )
  docs     = false
  examples = false
}

data "talos_machine_configuration" "worker" {
  // enable although we have no control planes to be able to debug the output
  count            = var.worker_count > 0 ? var.worker_count : 1
  talos_version    = var.talos_version
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_api_url_kube_prism
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = concat(
    [
      templatefile("${path.module}/patches/worker.yaml.tpl", {
        domain           = local.cluster_domain
        nodeSubnets      = local.node_ipv4_cidr
        serviceSubnets   = local.service_ipv4_cidr
        podSubnets       = local.pod_ipv4_cidr
        extraHostEntries = join(",", local.extra_host_entries)
      })
    ]
  )
  docs     = false
  examples = false
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
  kubeconfig = replace(
    data.talos_cluster_kubeconfig.this[0].kubeconfig_raw,
    local.cluster_api_url_kube_prism,
    "https://${local.control_plane_public_ipv4_list[0]}:${local.cluster_api_port_k8s}"
  )
}
