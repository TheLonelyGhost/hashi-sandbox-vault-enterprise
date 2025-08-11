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

data "vault_policy_document" "kv-monitor" {
  rule {
    description  = "Basic support for Vault Event Notifications feature"
    path         = "sys/events/subscribe/*"
    capabilities = ["read"]
  }

  rule {
    path         = "${vault_mount.kv.path}/*"
    capabilities = ["read", "update", "create", "list", "subscribe"]
    subscribe_event_types = [
      "kv-v2/data-delete",
      "kv-v2/data-patch",
      "kv-v2/data-write",
      "kv-v2/delete",
      "kv-v2/destroy",
    ]
  }
}
resource "vault_policy" "kv-monitor" {
  name   = "kv-monitor"
  policy = data.vault_policy_document.kv-monitor.hcl
}

resource "vault_approle_auth_backend_role" "sample" {
  backend   = vault_auth_backend.approle.path
  role_name = "sample"
  token_policies = [
    # vault_policy.admin.name,
    vault_policy.kv-monitor.name,
  ]

  token_ttl = 30
}
resource "vault_approle_auth_backend_role_secret_id" "sample" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.sample.role_name

  metadata = jsonencode({})
}
