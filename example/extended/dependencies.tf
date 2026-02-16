data "onepassword_item" "hetzner_token" {
  vault = var.op_vault_id_terraform
  uuid  = var.op_password_uuid_hetzner_token
}
