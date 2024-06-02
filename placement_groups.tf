resource "hcloud_placement_group" "control_plane" {
  name = "${local.cluster_prefix}control-plane"
  type = "spread"
  labels = {
    "cluster" = var.cluster_name
  }
}

resource "hcloud_placement_group" "worker" {
  name = "${local.cluster_prefix}worker"
  type = "spread"
  labels = {
    "cluster" = var.cluster_name
  }
}
