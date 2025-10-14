resource "vault_mount" "unseal" {
  type = "transit"
  path = "transit"
}

resource "vault_transit_secret_backend_key" "unseal" {
  backend = vault_mount.unseal.path
  name    = "my-sandbox-cluster"
}
