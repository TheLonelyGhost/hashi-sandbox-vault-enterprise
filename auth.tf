resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_approle_auth_backend_role" "sample" {
  backend   = vault_auth_backend.approle.path
  role_name = "sample"
  token_policies = [
    vault_policy.admin.name,
    # vault_policy.kv-monitor.name,
  ]

  token_ttl = 900
}
resource "vault_approle_auth_backend_role_secret_id" "sample" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.sample.role_name

  metadata = jsonencode({
    "generated-by" = "terraform"
  })
}

resource "vault_auth_backend" "tls" {
  type = "cert"
  path = "tls"
}

# resource "vault_cert_auth_backend_role" "sample" {
#   backend = vault_auth_backend.tls.path
# 
#   name        = "sample"
#   certificate = vault_pki_secret_backend_root_cert.main.certificate
# }

locals {
  oidCustomClearance      = "1.3.6.1.4.1.311.21.8.12.1"
  oidCustomClassification = "1.3.6.1.4.1.311.21.8.12.2"
}

resource "vault_generic_endpoint" "cert_config" {
  path = "auth/${vault_auth_backend.tls.path}/config"

  data_json = jsonencode({
    enable_metadata_on_failures    = true
    enable_identity_alias_metadata = true
  })
}

resource "vault_generic_endpoint" "sample_cert" {
  path = "auth/${vault_auth_backend.tls.path}/certs/sample"

  data_json = jsonencode({
    certificate = vault_pki_secret_backend_root_cert.main.certificate

    allowed_metadata_extensions = [
      local.oidCustomClearance,
      local.oidCustomClassification,
    ]

    token_policies = [
      vault_policy.templated_tls.name,
    ]
  })
}
