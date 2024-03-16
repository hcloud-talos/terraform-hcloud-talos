terraform {
  required_version = "1.7.5"
}

module "terraform-hcloud-talos" {
  source = "../terraform-hcloud-talos"

  hcloud_token = "" // Your hcloud token

  cluster_name    = "talos-cluster"
  datacenter_name = "fsn1-dc14"

  ssh_public_key = "" // e.g. file("~/.ssh/id_rsa.pub")"

  firewall_use_current_ip = true

  control_plane_count       = 3 // number of control planes to create
  control_plane_server_type = "cax21"

  worker_count       = 0 // number of worker to create
  worker_server_type = "cax21"
}
