locals {
  # https://github.com/hetznercloud/hcloud-cloud-controller-manager/blob/main/docs/deploy_with_networks.md#considerations-on-the-ip-ranges
  create_network           = var.network_id == null
  network_ipv4_cidr        = var.network_ipv4_cidr
  node_ipv4_cidr           = var.node_ipv4_cidr
  node_ipv4_cidr_mask_size = split("/", local.node_ipv4_cidr)[1] # 24
  pod_ipv4_cidr            = var.pod_ipv4_cidr
  service_ipv4_cidr        = var.service_ipv4_cidr

  # Resolved network ID: either the user-provided one or the one created by this module
  network_id = coalesce(
    var.network_id,
    try(hcloud_network.this[0].id, null)
  )

  # Resolved subnet CIDR for IP allocation: from the managed subnet or the variable
  node_ipv4_cidr_resolved = coalesce(
    try(hcloud_network_subnet.nodes[0].ip_range, null),
    var.node_ipv4_cidr
  )
}

resource "hcloud_network" "this" {
  count    = local.create_network ? 1 : 0
  name     = var.cluster_name
  ip_range = local.network_ipv4_cidr
  labels = {
    "cluster" = var.cluster_name
  }
}

resource "hcloud_network_subnet" "nodes" {
  count        = local.create_network ? 1 : 0
  network_id   = local.network_id
  type         = "cloud"
  network_zone = data.hcloud_location.selected.network_zone
  ip_range     = local.node_ipv4_cidr
}

resource "hcloud_network_route" "vpn" {
  for_each = { for idx, route in var.network_routes : idx => route }

  network_id  = local.network_id
  destination = each.value.destination
  gateway     = each.value.gateway
}

locals {
  create_floating_ip = var.enable_floating_ip && var.floating_ip == null
}

resource "hcloud_floating_ip" "control_plane_ipv4" {
  count             = local.create_floating_ip ? 1 : 0
  name              = "${local.cluster_prefix}control-plane-ipv4"
  type              = "ipv4"
  home_location     = data.hcloud_location.selected.name
  description       = "Control Plane VIP"
  delete_protection = false
  labels = {
    "cluster" = var.cluster_name,
    "role"    = "control-plane"
  }
}

data "hcloud_floating_ip" "control_plane_ipv4" {
  count = var.enable_floating_ip ? 1 : 0
  id = coalesce(
    can(var.floating_ip.id) ? var.floating_ip.id : null,
    local.create_floating_ip ? hcloud_floating_ip.control_plane_ipv4[0].id : null
  )
}

resource "hcloud_primary_ip" "control_plane_ipv4" {
  count         = local.control_plane_count
  name          = "${local.cluster_prefix}control-plane-${count.index + 1}-ipv4"
  location      = data.hcloud_location.selected.name
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false
  labels = {
    "cluster" = var.cluster_name,
    "role"    = "control-plane",
  }
}

resource "hcloud_primary_ip" "control_plane_ipv6" {
  count         = var.enable_ipv6 ? local.control_plane_count : 0
  name          = "${local.cluster_prefix}control-plane-${count.index + 1}-ipv6"
  location      = data.hcloud_location.selected.name
  type          = "ipv6"
  assignee_type = "server"
  auto_delete   = false
  labels = {
    "cluster" = var.cluster_name,
    "role"    = "control-plane",
  }
}

resource "hcloud_primary_ip" "worker_ipv4" {
  count         = local.worker_count
  name          = "${local.cluster_prefix}worker-${count.index + 1}-ipv4"
  location      = data.hcloud_location.selected.name
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false
  labels = {
    "cluster" = var.cluster_name,
    "role"    = "worker",
  }
}

resource "hcloud_primary_ip" "worker_ipv6" {
  count         = var.enable_ipv6 ? local.worker_count : 0
  name          = "${local.cluster_prefix}worker-${count.index + 1}-ipv6"
  location      = data.hcloud_location.selected.name
  type          = "ipv6"
  assignee_type = "server"
  auto_delete   = false
  labels = {
    "cluster" = var.cluster_name,
    "role"    = "worker",
  }
}

locals {
  control_plane_public_ipv4_list = [
    for ipv4 in hcloud_primary_ip.control_plane_ipv4 : ipv4.ip_address
  ]
  control_plane_public_ipv6_list = [
    for ipv6 in hcloud_primary_ip.control_plane_ipv6 : ipv6.ip_address
  ]
  control_plane_public_ipv6_subnet_list = [
    for ipv6 in hcloud_primary_ip.control_plane_ipv6 : ipv6.ip_network
  ]
  worker_public_ipv4_list = [
    for ipv4 in hcloud_primary_ip.worker_ipv4 : ipv4.ip_address
  ]
  worker_public_ipv6_list = [
    for ipv6 in hcloud_primary_ip.worker_ipv6 : ipv6.ip_address
  ]
  worker_public_ipv6_subnet_list = [
    for ipv6 in hcloud_primary_ip.worker_ipv6 : ipv6.ip_network
  ]

  # https://docs.hetzner.com/cloud/networks/faq/#are-any-ip-addresses-reserved
  # We may not use th following IP addresses:
  # - The first IP address of your network IP range. For example, in 10.0.0.0/8, you cannot use 10.0.0.1.
  # - The network and broadcast IP addresses of any subnet. For example, in 10.0.0.0/24, you cannot use 10.0.0.0 as well as 10.0.0.255.
  # - The special private IP address 172.31.1.1. This IP address is being used as a default gateway of your server's public network interface.
  control_plane_private_vip_ipv4 = cidrhost(local.node_ipv4_cidr_resolved, 100)
  control_plane_private_ipv4_list = [
    for index in range(local.control_plane_count) : cidrhost(local.node_ipv4_cidr_resolved, index + 101)
  ]
  worker_private_ipv4_list = [
    for index in range(local.worker_count) : cidrhost(local.node_ipv4_cidr_resolved, index + 201)
  ]
}
