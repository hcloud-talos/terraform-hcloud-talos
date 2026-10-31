mock_provider "hcloud" {}

variables {
  use_iso = true
}

run "plan_with_generated_iso_ids" {
  command = plan

  assert {
    condition = (
      output.arm.lookup_count == 0 && output.arm.image_id == "debian-13" &&
      output.x86.lookup_count == 0 && output.x86.image_id == "debian-13"
    )
    error_message = "Supplied ISOs must skip lookup and select a boot image before their IDs are known."
  }
}

run "apply_with_generated_iso_ids" {
  command = apply

  assert {
    condition     = output.arm.iso_id == "123456" && output.x86.iso_id == "234567"
    error_message = "Supplied ISOs must use the generated IDs."
  }
}
