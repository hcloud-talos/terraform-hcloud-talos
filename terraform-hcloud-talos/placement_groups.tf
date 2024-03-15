resource "hcloud_placement_group" "control_plane" {
  name = "control-plane"
  type = "spread"
}

resource "hcloud_placement_group" "worker" {
  name = "worker"
  type = "spread"
}
