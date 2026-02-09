resource "vault_mount" "kv" {
  path = "kv/my-thing"
  type = "kv-v2"
}

# NOTE: Sometimes the below line is needed due to (seemingly) race
# conditions within the Vault provider. Uncomment as needed.
#
# import {
#   id = "kv/my-thing"
#   to = vault_mount.kv
# }
