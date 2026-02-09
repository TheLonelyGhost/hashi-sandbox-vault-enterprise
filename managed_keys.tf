locals {
  vault_addr         = var.vault_addr # "https://127.0.0.1:8200"
  managed_key_name   = "example-key"
  managed_key_name_2 = "other-key"
  pkcs11_mechanisms = {
    "CKM_ECDSA"         = "0x1041"
    "CKM_RSA_PKCS_PSS"  = "0x000D"
    "CKM_RSA_PKCS_OAEP" = "0x0009"
    "CKM_RSA_PKCS"      = "0x0001"
  }
}

resource "vault_generic_endpoint" "managed_key_first" {
  path = "sys/managed-keys/pkcs11/${local.managed_key_name}"
  data_json = jsonencode({
    library     = "softhsm-server"
    token_label = "Test Token"
    pin         = "1234" # TODO: Sensitive, if this were a real HSM
    mechanism   = local.pkcs11_mechanisms["CKM_RSA_PKCS"]
    key_bits    = 3072

    allow_generate_key = "true" # TODO: Disable this once generated to prevent catastrophe

    key_label = "Example Key"
    usages = join(",", [
      # "encrypt",
      # "decrypt",
      "sign",
      "verify",
      # "wrap",
      # "unwrap",
      # "mac",
      # "random",
    ])
  })

  disable_read = true
}

resource "vault_generic_endpoint" "managed_key_second" {
  path = "sys/managed-keys/pkcs11/${local.managed_key_name_2}"
  data_json = jsonencode({
    library     = "softhsm-server"
    token_label = "Test Token"
    pin         = "1234" # TODO: Sensitive, if this were a real HSM
    mechanism   = local.pkcs11_mechanisms["CKM_RSA_PKCS"]
    key_bits    = 4096

    allow_generate_key = "true" # TODO: Disable this once generated to prevent catastrophe

    key_label = "Other Key"
    usages = join(",", [
      # "encrypt",
      # "decrypt",
      "sign",
      "verify",
      # "wrap",
      # "unwrap",
      # "mac",
      # "random",
    ])
  })

  disable_read = true
}

resource "vault_mount" "pki" {
  path = "pki/intermediate-example"
  type = "pki"

  description = "Internally-signed PKI intermediate CA"

  allowed_managed_keys = [
    local.managed_key_name,
    local.managed_key_name_2,
  ]
}

resource "vault_pki_secret_backend_config_urls" "pki" {
  backend = vault_mount.pki.path

  issuing_certificates = [
    "${local.vault_addr}/v1/${vault_mount.pki.path}/ca",
  ]
}

resource "vault_pki_secret_backend_intermediate_cert_request" "trusted" {
  backend = vault_mount.pki.path

  type             = "kms"
  managed_key_name = local.managed_key_name

  common_name  = "Vault Trusted Intermediate"
  organization = "Acme Corp"
  country      = "US"
  # alt_names             = []
  # uri_sans              = []
  # ip_sans               = []
  exclude_cn_from_sans  = true
  add_basic_constraints = true
  key_usage = [
    "DigitalSignature",
    "ContentCommitment",
    "CertSign",
    "CRLSign",
  ]
}

resource "vault_pki_secret_backend_intermediate_cert_request" "untrusted" {
  backend = vault_mount.pki.path

  type             = "kms"
  managed_key_name = local.managed_key_name_2

  common_name  = "Vault Untrusted Intermediate"
  organization = "Acme Corp"
  country      = "US"
  # alt_names             = []
  # uri_sans              = []
  # ip_sans               = []
  exclude_cn_from_sans  = true
  add_basic_constraints = true
  key_usage = [
    "DigitalSignature",
    "ContentCommitment",
    "CertSign",
    "CRLSign",
  ]
}
# resource "vault_generic_endpoint" "pki_intermediate_untrusted_csr" {
#   path = "${vault_mount.pki.path}/issuers/generate/intermediate/kms"
#   data_json = jsonencode({
#     managed_key_name = local.managed_key_name_2
# 
#     common_name = "Vault Trusted Intermediate"
#     # ou           = [""]
#     organization = "Acme Corp"
#     country      = "US"
# 
#     key_usage = []
# 
#     add_basic_constraints = true
#     exclude_cn_from_sans  = true
#   })
# 
#   write_fields = ["csr"]
# 
#   disable_read   = true
#   disable_delete = true
# }


output "intermediate_csr" {
  description = "Intermediate Certificate Authority's Certificate Signing Request for the Root CA"
  value = {
    "trusted"   = vault_pki_secret_backend_intermediate_cert_request.trusted.csr
    "untrusted" = vault_pki_secret_backend_intermediate_cert_request.untrusted.csr
  }
}

resource "vault_pki_secret_backend_intermediate_set_signed" "trusted" {
  backend = vault_mount.pki.path

  certificate = vault_pki_secret_backend_root_sign_intermediate.trusted.certificate
}
resource "vault_pki_secret_backend_issuer" "trusted" {
  backend = vault_mount.pki.path

  issuer_ref  = vault_pki_secret_backend_intermediate_set_signed.trusted.imported_issuers[0]
  issuer_name = "trusted"
}

resource "vault_pki_secret_backend_intermediate_set_signed" "untrusted" {
  backend = vault_mount.pki.path

  certificate = vault_pki_secret_backend_root_sign_intermediate.untrusted.certificate
}
resource "vault_pki_secret_backend_issuer" "untrusted" {
  backend = vault_mount.pki.path

  issuer_ref  = vault_pki_secret_backend_intermediate_set_signed.untrusted.imported_issuers[0]
  issuer_name = "untrusted"
}

resource "vault_pki_secret_backend_config_issuers" "pki" {
  backend = vault_mount.pki.path

  default                       = vault_pki_secret_backend_issuer.untrusted.issuer_id
  default_follows_latest_issuer = false
}

# output "intermediate_issuers" {
#   value = {
#     "trusted"   = vault_pki_secret_backend_intermediate_set_signed.trusted.imported_issuers
#     "untrusted" = vault_pki_secret_backend_intermediate_set_signed.untrusted.imported_issuers
#   }
# }
