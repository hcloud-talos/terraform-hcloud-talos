data "hcloud_image" "arm" {
  count             = var.disable_arm || local.arm_image != null || local.arm_iso != null ? 0 : 1
  with_selector     = "os=talos,version=${var.talos_version}"
  with_architecture = "arm"
  most_recent       = true
}

data "hcloud_image" "x86" {
  count             = var.disable_x86 || local.x86_image != null || local.x86_iso != null ? 0 : 1
  with_selector     = "os=talos,version=${var.talos_version}"
  with_architecture = "x86"
  most_recent       = true
}

locals {
  # Keep the source object separate from its ID, which can remain unknown until apply.
  arm_image = var.talos_image_arm != null ? var.talos_image_arm : (
    var.talos_image_id_arm != null ? { id = var.talos_image_id_arm } : null
  )
  x86_image = var.talos_image_x86 != null ? var.talos_image_x86 : (
    var.talos_image_id_x86 != null ? { id = var.talos_image_id_x86 } : null
  )
  arm_iso = var.talos_iso_arm != null ? var.talos_iso_arm : (
    var.talos_iso_id_arm != null ? { id = var.talos_iso_id_arm } : null
  )
  x86_iso = var.talos_iso_x86 != null ? var.talos_iso_x86 : (
    var.talos_iso_id_x86 != null ? { id = var.talos_iso_id_x86 } : null
  )

  # hcloud requires `image` for server creation even when an `iso` is attached.
  default_iso_boot_image = "debian-13"

  arm_image_id = (
    local.arm_image != null ? local.arm_image.id :
    local.arm_iso != null ? local.default_iso_boot_image :
    (var.disable_arm || length(data.hcloud_image.arm) == 0 ? null : data.hcloud_image.arm[0].id)
  )

  x86_image_id = (
    local.x86_image != null ? local.x86_image.id :
    local.x86_iso != null ? local.default_iso_boot_image :
    (var.disable_x86 || length(data.hcloud_image.x86) == 0 ? null : data.hcloud_image.x86[0].id)
  )

  arm_iso_id = var.disable_arm || local.arm_iso == null ? null : local.arm_iso.id
  x86_iso_id = var.disable_x86 || local.x86_iso == null ? null : local.x86_iso.id
}
