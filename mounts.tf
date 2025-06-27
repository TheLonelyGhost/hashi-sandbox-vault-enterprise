resource "vault_mount" "kv" {
  path = "kv/my-thing"
  type = "kv-v2"
}
