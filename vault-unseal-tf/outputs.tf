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
  content         = <<-EOH
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

resource "local_sensitive_file" "server_pk" {
  content         = vault_pki_secret_backend_cert.vault.private_key
  file_permission = "0600"

  filename = "${path.module}/../vault-config/server.pem"
}

resource "local_file" "server_crt" {
  content         = vault_pki_secret_backend_cert.vault.certificate
  file_permission = "0644"

  filename = "${path.module}/../vault-config/server.crt"
}

resource "local_file" "server_ca" {
  content         = vault_pki_secret_backend_cert.vault.ca_chain
  file_permission = "0644"

  filename = "${path.module}/../vault-config/server.ca.crt"
}

resource "local_file" "server_crt_bundle" {
  content = join("\n", [
    vault_pki_secret_backend_cert.vault.certificate,
    vault_pki_secret_backend_cert.vault.ca_chain,
  ])
  file_permission = "0644"

  filename = "${path.module}/../vault-config/server.bundle.crt"
}
