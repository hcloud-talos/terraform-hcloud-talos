locals {
  # Sources and update steps are in SUPPORTED_VERSIONS.md.
  supported_talos_versions = jsondecode(file("${path.module}/supported_versions.json"))
  stable_version_pattern   = "(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)"
  talos_version_parts      = try(regex("^v${local.stable_version_pattern}$", var.talos_version), ["0", "0", "0"])
  talos_minor              = join(".", slice(local.talos_version_parts, 0, 2))
  talos_support            = lookup(local.supported_talos_versions, local.talos_minor, null)
  talos_version_supported  = try(tonumber(local.talos_version_parts[2]) >= local.talos_support.minimum_patch, false)

  supported_talos_description = join(" or ", [
    for minor, support in local.supported_talos_versions : "v${minor}.${support.minimum_patch} or a later stable ${minor}.x patch"
  ])
}
