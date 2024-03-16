data "hcloud_image" "arm" {
  with_selector     = "os=talos"
  with_architecture = "arm"
  most_recent       = true
}

data "hcloud_image" "x86" {
  with_selector     = "os=talos"
  with_architecture = "x86"
  most_recent       = true
}

locals {
  control_plane_image_id = substr(var.control_plane_server_type, 0, 3) == "cax" ? data.hcloud_image.arm.id : data.hcloud_image.x86.id
  worker_image_id        = substr(var.worker_server_type, 0, 3) == "cax" ? data.hcloud_image.arm.id : data.hcloud_image.x86.id
}

resource "hcloud_ssh_key" "this" {
  name       = "default"
  public_key = var.ssh_public_key
}

resource "hcloud_primary_ip" "control_planes" {
  count         = var.control_plane_count
  name          = "control-plane-${count.index + 1}"
  datacenter    = data.hcloud_datacenter.this.name
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false
}

resource "hcloud_server" "control_planes" {
  count              = var.control_plane_count
  datacenter         = data.hcloud_datacenter.this.name
  name               = "control-plane-${count.index + 1}"
  image              = local.control_plane_image_id
  server_type        = var.control_plane_server_type
  user_data          = data.talos_machine_configuration.control_plane[count.index].machine_configuration
  ssh_keys           = [hcloud_ssh_key.this.id]
  placement_group_id = hcloud_placement_group.control_plane.id

  labels = {
    "role" = "control-plane"
  }

  firewall_ids = [
    hcloud_firewall.this.id
  ]

  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.control_planes[count.index].id
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network_subnet.control_plane.network_id
    ip         = local.control_plane_ips[count.index]
  }

  depends_on = [
    hcloud_network_subnet.control_plane,
    data.talos_machine_configuration.control_plane
  ]
}

resource "hcloud_primary_ip" "workers" {
  count         = var.worker_count
  name          = "worker-${count.index + 1}"
  datacenter    = data.hcloud_datacenter.this.name
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false
}

resource "hcloud_server" "workers" {
  count              = var.worker_count
  datacenter         = data.hcloud_datacenter.this.name
  name               = "worker-${count.index + 1}"
  image              = local.worker_image_id
  server_type        = var.worker_server_type
  user_data          = data.talos_machine_configuration.worker[count.index].machine_configuration
  ssh_keys           = [hcloud_ssh_key.this.id]
  placement_group_id = hcloud_placement_group.worker.id

  labels = {
    "role" = "worker"
  }

  firewall_ids = [
    hcloud_firewall.this.id
  ]

  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.workers[count.index].id
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network_subnet.worker.network_id
    ip         = local.worker_ips[count.index]
  }

  depends_on = [
    hcloud_network_subnet.worker,
    data.talos_machine_configuration.worker
  ]
}
