output "root_token" {
  description = "Root token for the vault cluster"
  value       = nonsensitive(vaultstarter_init.base.root_token)

  depends_on = [terraform_data.root_token]
}

output "shamir_keys" {
  description = "Shamir unseal keys"
  value       = nonsensitive(vaultstarter_init.base.keys)

  depends_on = [terraform_data.root_token]
}

resource "local_sensitive_file" "unseal_hcl" {
  content         = <<EOH
  seal "transit" {
    disable_renewal = "true"
    token           = "${vaultstarter_init.base.root_token}"

    key_name   = "${vault_transit_secret_backend_key.unseal.name}"
    mount_path = "${vault_transit_secret_backend_key.unseal.backend}"
    address    = "http://vault-unseal:8300"
  }
  EOH
  file_permission = "0600"

  filename = "${path.module}/../vault-config/unseal.hcl"
}
