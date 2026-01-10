data "hcloud_locations" "all" {}

data "hcloud_location" "selected" {
  name = var.location_name
}
