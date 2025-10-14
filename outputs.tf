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
  value       = nonsensitive(terraform_data.root_token.output)
}

output "recovery_keys" {
  description = "Recovery keys"
  value       = nonsensitive(vaultoperator_init.base.recovery_keys)

  depends_on = [terraform_data.root_token]
}

resource "local_sensitive_file" "env" {
  content         = <<-EOH
  VAULT_ROOT_TOKEN='${terraform_data.root_token.output}'
  VAULT_ROLE_ID='${vault_approle_auth_backend_role.sample.role_id}'
  VAULT_SECRET_ID='${vault_approle_auth_backend_role_secret_id.sample.secret_id}'

  export VAULT_ADDR='${var.vault_addr}'
  export VAULT_CACERT="$(pwd)/vault-config/server.ca.crt"
  export VAULT_CLIENT_TIMEOUT='10s'
  export VAULT_TLS_SERVERNAME='my-sandbox-cluster.localhost'
  EOH
  file_permission = "0600"

  filename = "${path.module}/.env"
}
