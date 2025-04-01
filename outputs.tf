output "approle" {
  value = {
    sample_user = {
      role_id   = nonsensitive(vault_approle_auth_backend_role.sample.role_id)
      secret_id = nonsensitive(vault_approle_auth_backend_role_secret_id.sample.secret_id)
    }
  }
}

output "root_token" {
  description = "Root token for the vault cluster"
  value       = nonsensitive(vaultstarter_init.base.root_token)

  depends_on = [null_resource.root_token]
}

output "shamir_keys" {
  description = "Shamir unseal keys"
  value       = nonsensitive(vaultstarter_init.base.keys)

  depends_on = [null_resource.root_token]
}
