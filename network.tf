resource "hcloud_network" "this" {
  name     = var.cluster_name
  ip_range = var.network_ipv4_cidr
}

resource "hcloud_network_subnet" "control_plane" {
  network_id   = hcloud_network.this.id
  type         = "cloud"
  network_zone = data.hcloud_location.this.network_zone
  ip_range     = cidrsubnet(var.network_ipv4_cidr, 8, 0)
}

resource "hcloud_network_subnet" "worker" {
  network_id   = hcloud_network.this.id
  type         = "cloud"
  network_zone = data.hcloud_location.this.network_zone
  ip_range     = cidrsubnet(var.network_ipv4_cidr, 8, 1)
}

# https://docs.hetzner.com/cloud/networks/faq/#are-any-ip-addresses-reserved
# We may not use th following IP addresses:
# - The first IP address of your network IP range. For example, in 10.0.0.0/8, you cannot use 10.0.0.1.
# - The network and broadcast IP addresses of any subnet. For example, in 10.0.0.0/24, you cannot use 10.0.0.0 as well as 10.0.0.255.
# - The special private IP address 172.31.1.1. This IP address is being used as a default gateway of your server's public network interface.
locals {
  control_plane_ips = [
    for index in range(var.control_plane_count) : cidrhost(hcloud_network_subnet.control_plane.ip_range, index + 101)
  ]
  worker_ips = [
    for index in range(var.worker_count) : cidrhost(hcloud_network_subnet.worker.ip_range, index + 201)
  ]
}