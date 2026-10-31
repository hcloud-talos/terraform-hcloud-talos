variable "location_name" {
  type        = string
  description = <<EOF
    The name of the location where the cluster will be created.
    This is used to determine the region and zone of the cluster and network.
    Possible values: fsn1, nbg1, hel1, ash, hil, sin
  EOF
  validation {
    # .names is deprecated, but .locations cannot be mocked to a non-empty list in terraform test.
    condition     = contains(data.hcloud_locations.all.names, var.location_name)
    error_message = "Invalid location name."
  }
}

data "hcloud_locations" "all" {}

data "hcloud_location" "selected" {
  name = var.location_name
}
