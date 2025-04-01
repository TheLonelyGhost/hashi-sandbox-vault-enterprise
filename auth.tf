resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_auth_backend" "jwt" {
  type = "jwt"
}

resource "vault_jwt_auth_backend_role" "me" {
  backend = vault_auth_backend.jwt.path

  role_type  = "jwt"
  role_name  = "foo"
  user_claim = "iss"

  bound_claims_type = "glob"
  bound_claims = {
    sub = "*"
  }
}

resource "vault_policy" "admin" {
  name   = "super-admin"
  policy = <<-EOH
  path "*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }
  EOH
}

resource "vault_approle_auth_backend_role" "sample" {
  backend   = vault_auth_backend.approle.path
  role_name = "sample"
  token_policies = [
    vault_policy.admin.name,
  ]
}
resource "vault_approle_auth_backend_role_secret_id" "sample" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.sample.role_name

  metadata = jsonencode({})
}
