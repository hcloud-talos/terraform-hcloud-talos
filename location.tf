data "hcloud_locations" "all" {}

data "hcloud_location" "this" {
  name = var.location_name
}
