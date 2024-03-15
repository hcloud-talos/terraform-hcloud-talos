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
