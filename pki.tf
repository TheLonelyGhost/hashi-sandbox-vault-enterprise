resource "vault_mount" "pki" {
  type = "pki"
  path = "pki"

  description = "temporary PKI issuer for local development"

  default_lease_ttl_seconds = 365 * 24 * 60 * 60 # 1 year
  max_lease_ttl_seconds     = 365 * 24 * 60 * 60 # 1 year
}

resource "vault_pki_secret_backend_config_urls" "main" {
  backend = vault_mount.pki.path
  issuing_certificates = [
    "${var.vault_addr}/v1/${vault_mount.pki.path}/ca", # Must be the endpoint serving DER-formatted content
  ]
}

resource "vault_pki_secret_backend_crl_config" "main" {
  backend = vault_mount.pki.path
  expiry  = "72h"
  disable = false
}

resource "vault_pki_secret_backend_root_cert" "main" {
  backend              = vault_mount.pki.path
  type                 = "internal"
  common_name          = "Local Dev Root CA"
  ttl                  = tostring(10 * 365 * 24 * 60 * 60) # 10 years
  format               = "pem"
  private_key_format   = "der"
  key_type             = "rsa"
  key_bits             = 4096
  exclude_cn_from_sans = true
  ou                   = "My OU"
  organization         = "My organization"
}

resource "vault_pki_secret_backend_issuer" "main" {
  backend     = vault_pki_secret_backend_root_cert.main.backend
  issuer_ref  = vault_pki_secret_backend_root_cert.main.issuer_id
  issuer_name = "main"
}

resource "vault_pki_secret_backend_config_issuers" "main" {
  backend                       = vault_mount.pki.path
  default                       = vault_pki_secret_backend_issuer.main.issuer_id
  default_follows_latest_issuer = true
}

resource "terraform_data" "pki_mount" {
  input = vault_mount.pki.path

  depends_on = [
    vault_pki_secret_backend_issuer.main,
    vault_pki_secret_backend_config_issuers.main,
    vault_pki_secret_backend_config_urls.main,
  ]
}

resource "vault_pki_secret_backend_role" "client" {
  backend    = terraform_data.pki_mount.output
  issuer_ref = vault_pki_secret_backend_issuer.main.issuer_id
  name       = "client"

  allow_any_name  = true
  client_flag     = true
  allow_localhost = true
  cn_validations  = ["disabled"]

  key_type = "ed25519"
  key_bits = 2048

  no_store       = true
  generate_lease = false
}
