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

resource "vault_cert_auth_backend_role" "sample" {
  backend = vault_auth_backend.tls.path

  name        = "sample"
  certificate = vault_pki_secret_backend_root_cert.main.certificate
}
