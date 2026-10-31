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

run "reject_unsupported_talos_minor" {
  command = plan
  variables { talos_version = "v1.12.4" }
  expect_failures = [var.talos_version]
}

run "reject_future_talos_minor" {
  command = plan
  variables { talos_version = "v1.15.0" }
  expect_failures = [var.talos_version]
}

run "reject_future_talos_major" {
  command = plan
  variables { talos_version = "v2.14.3" }
  expect_failures = [var.talos_version]
}

run "reject_old_1_13_patch" {
  command = plan
  variables { talos_version = "v1.13.10" }
  expect_failures = [var.talos_version]
}

run "reject_old_1_14_patch" {
  command = plan
  variables { talos_version = "v1.14.2" }
  expect_failures = [var.talos_version]
}

run "accept_later_1_13_patch" {
  command = plan
  variables { talos_version = "v1.13.100" }
}

run "accept_later_1_14_patch" {
  command = plan
  variables { talos_version = "v1.14.100" }
}

run "reject_talos_prerelease" {
  command = plan
  variables { talos_version = "v1.14.4-rc.1" }
  expect_failures = [var.talos_version]
}

run "reject_talos_build_metadata" {
  command = plan
  variables { talos_version = "v1.14.3+custom" }
  expect_failures = [var.talos_version]
}

run "reject_talos_without_prefix" {
  command = plan
  variables { talos_version = "1.14.3" }
  expect_failures = [var.talos_version]
}

run "reject_talos_missing_patch" {
  command = plan
  variables { talos_version = "v1.14" }
  expect_failures = [var.talos_version]
}

run "reject_talos_leading_zero" {
  command = plan
  variables { talos_version = "v1.14.03" }
  expect_failures = [var.talos_version]
}

run "reject_talos_empty" {
  command = plan
  variables { talos_version = "" }
  expect_failures = [var.talos_version]
}

run "accept_1_13_kubernetes_minimum" {
  command = plan
  variables {
    talos_version      = "v1.13.11"
    kubernetes_version = "1.31.0"
  }
}

run "accept_1_13_kubernetes_maximum" {
  command = plan
  variables {
    talos_version      = "v1.13.11"
    kubernetes_version = "1.36.98"
  }
}

run "reject_1_13_kubernetes_too_old" {
  command = plan
  variables {
    talos_version      = "v1.13.11"
    kubernetes_version = "1.30.14"
  }
  expect_failures = [var.kubernetes_version]
}

run "reject_1_13_kubernetes_too_new" {
  command = plan
  variables {
    talos_version      = "v1.13.11"
    kubernetes_version = "1.37.0"
  }
  expect_failures = [var.kubernetes_version]
}

run "reject_1_13_kubernetes_upper_bound" {
  command = plan
  variables {
    talos_version      = "v1.13.11"
    kubernetes_version = "1.36.99"
  }
  expect_failures = [var.kubernetes_version]
}

run "accept_1_14_kubernetes_minimum" {
  command = plan
  variables { kubernetes_version = "1.32.0" }
}

run "accept_1_14_kubernetes_maximum" {
  command = plan
  variables { kubernetes_version = "1.37.98" }
}

run "reject_1_14_kubernetes_too_old" {
  command = plan
  variables { kubernetes_version = "1.31.14" }
  expect_failures = [var.kubernetes_version]
}

run "reject_1_14_kubernetes_too_new" {
  command = plan
  variables { kubernetes_version = "1.38.0" }
  expect_failures = [var.kubernetes_version]
}

run "reject_1_14_kubernetes_upper_bound" {
  command = plan
  variables { kubernetes_version = "1.37.99" }
  expect_failures = [var.kubernetes_version]
}

run "reject_kubernetes_prerelease" {
  command = plan
  variables { kubernetes_version = "1.35.0-rc.1" }
  expect_failures = [var.kubernetes_version]
}

run "reject_kubernetes_build_metadata" {
  command = plan
  variables { kubernetes_version = "1.35.0+custom" }
  expect_failures = [var.kubernetes_version]
}

run "reject_kubernetes_prefix" {
  command = plan
  variables { kubernetes_version = "v1.35.0" }
  expect_failures = [var.kubernetes_version]
}

run "reject_kubernetes_missing_patch" {
  command = plan
  variables { kubernetes_version = "1.35" }
  expect_failures = [var.kubernetes_version]
}

run "reject_kubernetes_leading_zero" {
  command = plan
  variables { kubernetes_version = "1.35.01" }
  expect_failures = [var.kubernetes_version]
}

run "reject_kubernetes_major" {
  command = plan
  variables { kubernetes_version = "2.35.0" }
  expect_failures = [var.kubernetes_version]
}

run "reject_kubernetes_empty" {
  command = plan
  variables { kubernetes_version = "" }
  expect_failures = [var.kubernetes_version]
}
