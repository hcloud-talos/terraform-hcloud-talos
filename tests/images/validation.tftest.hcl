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

run "reject_malformed_image_ids" {
  command = plan
  module { source = "./module" }
  variables {
    talos_image_arm = { id = "invalid" }
    talos_image_x86 = { id = "" }
  }
  expect_failures = [var.talos_image_arm, var.talos_image_x86]
}

run "reject_malformed_iso_ids" {
  command = plan
  module { source = "./module" }
  variables {
    talos_iso_arm = { id = "" }
    talos_iso_x86 = { id = "invalid" }
  }
  expect_failures = [var.talos_iso_arm, var.talos_iso_x86]
}

run "reject_null_image_object_ids" {
  command = plan
  module { source = "./module" }
  variables {
    talos_image_arm = { id = null }
    talos_image_x86 = { id = null }
  }
  expect_failures = [var.talos_image_arm, var.talos_image_x86]
}

run "reject_null_iso_object_ids" {
  command = plan
  module { source = "./module" }
  variables {
    talos_iso_arm = { id = null }
    talos_iso_x86 = { id = null }
  }
  expect_failures = [var.talos_iso_arm, var.talos_iso_x86]
}

run "reject_image_objects_with_legacy_images" {
  command = plan
  module { source = "./module" }
  variables {
    talos_image_arm    = { id = "123456" }
    talos_image_x86    = { id = "234567" }
    talos_image_id_arm = "123456"
    talos_image_id_x86 = "234567"
  }
  expect_failures = [var.talos_image_arm, var.talos_image_x86]
}

run "reject_image_objects_with_legacy_isos" {
  command = plan
  module { source = "./module" }
  variables {
    talos_image_arm  = { id = "123456" }
    talos_image_x86  = { id = "234567" }
    talos_iso_id_arm = "123456"
    talos_iso_id_x86 = "234567"
  }
  expect_failures = [var.talos_image_arm, var.talos_image_x86]
}

run "reject_iso_objects_with_legacy_images" {
  command = plan
  module { source = "./module" }
  variables {
    talos_iso_arm      = { id = "123456" }
    talos_iso_x86      = { id = "234567" }
    talos_image_id_arm = "123456"
    talos_image_id_x86 = "234567"
  }
  expect_failures = [var.talos_iso_arm, var.talos_iso_x86]
}

run "reject_iso_objects_with_legacy_isos" {
  command = plan
  module { source = "./module" }
  variables {
    talos_iso_arm    = { id = "123456" }
    talos_iso_x86    = { id = "234567" }
    talos_iso_id_arm = "123456"
    talos_iso_id_x86 = "234567"
  }
  expect_failures = [var.talos_iso_arm, var.talos_iso_x86]
}

run "reject_image_objects_with_iso_objects" {
  command = plan
  module { source = "./module" }
  variables {
    talos_image_arm = { id = "123456" }
    talos_image_x86 = { id = "234567" }
    talos_iso_arm   = { id = "123456" }
    talos_iso_x86   = { id = "234567" }
  }
  expect_failures = [var.talos_iso_arm, var.talos_iso_x86]
}
