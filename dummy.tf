# This is a dummy certificate for testing purposes only. It is not secure and should not be used in production.
resource "tls_private_key" "dummy_ca" {
  count       = var.control_plane_count > 0 ? 0 : 1
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "dummy_ca" {
  count                 = var.control_plane_count > 0 ? 0 : 1
  private_key_pem       = tls_private_key.dummy_ca[0].private_key_pem
  is_ca_certificate     = true
  set_subject_key_id    = true
  validity_period_hours = 87600
  allowed_uses = [
    "cert_signing",
    "crl_signing"
  ]
  subject {
    common_name = "dummy.cluster.local"
  }
}

resource "tls_private_key" "dummy_issuer" {
  count       = var.control_plane_count > 0 ? 0 : 1
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "dummy_issuer" {
  count           = var.control_plane_count > 0 ? 0 : 1
  private_key_pem = tls_private_key.dummy_issuer[0].private_key_pem
  subject {
    common_name = "dummy.cluster.local"
  }
}

resource "tls_locally_signed_cert" "dummy_issuer" {
  count                 = var.control_plane_count > 0 ? 0 : 1
  cert_request_pem      = tls_cert_request.dummy_issuer[0].cert_request_pem
  ca_private_key_pem    = tls_private_key.dummy_ca[0].private_key_pem
  ca_cert_pem           = tls_self_signed_cert.dummy_ca[0].cert_pem
  is_ca_certificate     = true
  set_subject_key_id    = true
  validity_period_hours = 8760
  allowed_uses = [
    "cert_signing",
    "crl_signing"
  ]
}