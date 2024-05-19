resource "hcloud_placement_group" "control_plane" {
  name = "${local.cluster_prefix}control-plane"
  type = "spread"
}

resource "hcloud_placement_group" "worker" {
  name = "${local.cluster_prefix}worker"
  type = "spread"
}
