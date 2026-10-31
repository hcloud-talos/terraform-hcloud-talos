mock_provider "hcloud" {}

variables {
  hcloud_token       = "test-token"
  cluster_name       = "test"
  talos_version      = "v1.14.3"
  kubernetes_version = "1.35.0"
  control_plane_nodes = [{
    id   = 1
    type = "cx23"
  }]
}

run "default_image_lookup" {
  command = plan
  module { source = "./module" }

  assert {
    condition = (
      output.arm.lookup_count == 1 && output.arm.iso_id == null &&
      output.x86.lookup_count == 1 && output.x86.iso_id == null
    )
    error_message = "Without supplied sources, both architectures must use image lookup."
  }

  assert {
    condition = (
      data.hcloud_image.arm[0].with_selector == "os=talos,version=v1.14.3" &&
      data.hcloud_image.arm[0].with_architecture == "arm" && data.hcloud_image.arm[0].most_recent &&
      data.hcloud_image.x86[0].with_selector == "os=talos,version=v1.14.3" &&
      data.hcloud_image.x86[0].with_architecture == "x86" && data.hcloud_image.x86[0].most_recent
    )
    error_message = "Image lookup must select the latest Talos image for the configured version and architecture."
  }
}

run "disabled_arm_lookup" {
  command = plan
  module { source = "./module" }
  variables { disable_arm = true }

  assert {
    condition = (
      output.arm.lookup_count == 0 && output.arm.image_id == null && output.arm.iso_id == null &&
      output.x86.lookup_count == 1
    )
    error_message = "Disabling ARM lookup must not change x86 lookup."
  }
}

run "disabled_x86_lookup" {
  command = plan
  module { source = "./module" }
  variables { disable_x86 = true }

  assert {
    condition = (
      output.arm.lookup_count == 1 &&
      output.x86.lookup_count == 0 && output.x86.image_id == null && output.x86.iso_id == null
    )
    error_message = "Disabling x86 lookup must not change ARM lookup."
  }
}

run "legacy_iso_ids" {
  command = plan
  module { source = "./module" }
  variables {
    talos_iso_id_arm = "123456"
    talos_iso_id_x86 = "234567"
  }

  assert {
    condition = (
      output.arm.lookup_count == 0 && output.arm.image_id == "debian-13" && output.arm.iso_id == "123456" &&
      output.x86.lookup_count == 0 && output.x86.image_id == "debian-13" && output.x86.iso_id == "234567"
    )
    error_message = "Legacy ISO IDs must retain their behavior."
  }
}

run "legacy_image_and_iso_ids" {
  command = plan
  module { source = "./module" }
  variables {
    talos_image_id_arm = "123456"
    talos_image_id_x86 = "234567"
    talos_iso_id_arm   = "456789"
    talos_iso_id_x86   = "567890"
  }

  assert {
    condition = (
      output.arm.lookup_count == 0 && output.arm.image_id == "123456" && output.arm.iso_id == "456789" &&
      output.x86.lookup_count == 0 && output.x86.image_id == "234567" && output.x86.iso_id == "567890"
    )
    error_message = "Legacy configurations must still allow a supplied image with an ISO."
  }
}

run "disabled_lookup_with_supplied_images" {
  command = plan
  module { source = "./module" }
  variables {
    disable_arm        = true
    disable_x86        = true
    talos_image_arm    = { id = "123456" }
    talos_image_id_x86 = "234567"
  }

  assert {
    condition = (
      output.arm.lookup_count == 0 && output.arm.image_id == "123456" && output.arm.iso_id == null &&
      output.x86.lookup_count == 0 && output.x86.image_id == "234567" && output.x86.iso_id == null
    )
    error_message = "Disabling lookup must not suppress new or legacy image inputs."
  }
}

run "disabled_supplied_isos" {
  command = plan
  module { source = "./module" }
  variables {
    disable_arm      = true
    disable_x86      = true
    talos_iso_arm    = { id = "123456" }
    talos_iso_id_x86 = "234567"
  }

  assert {
    condition = (
      output.arm.lookup_count == 0 && output.arm.image_id == "debian-13" && output.arm.iso_id == null &&
      output.x86.lookup_count == 0 && output.x86.image_id == "debian-13" && output.x86.iso_id == null
    )
    error_message = "Disabling an architecture must suppress new and legacy ISO attachment."
  }
}
