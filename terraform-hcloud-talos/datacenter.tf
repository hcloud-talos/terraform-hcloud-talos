data "hcloud_datacenter" "this" {
  name = var.datacenter_name
}

data "hcloud_location" "this" {
  id = data.hcloud_datacenter.this.location.id
}
