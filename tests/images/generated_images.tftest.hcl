mock_provider "hcloud" {}

run "plan_with_generated_image_ids" {
  command = plan

  assert {
    condition     = output.arm.lookup_count == 0 && output.x86.lookup_count == 0
    error_message = "Supplied images must skip lookup before their IDs are known."
  }
}

run "apply_with_generated_image_ids" {
  command = apply

  assert {
    condition = (
      output.arm.image_id == "123456" && output.arm.iso_id == null &&
      output.x86.image_id == "234567" && output.x86.iso_id == null
    )
    error_message = "Supplied images must use the generated IDs without ISO attachment."
  }
}
