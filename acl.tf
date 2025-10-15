data "vault_policy_document" "superadmin" {
  rule {
    description  = "Super-admin capabilities"
    path         = "*"
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }

  rule {
    description           = "Subscribe to event notifications"
    path                  = "*"
    capabilities          = ["subscribe"]
    subscribe_event_types = ["*"]
  }
}
resource "vault_policy" "admin" {
  name   = "super-admin"
  policy = data.vault_policy_document.superadmin.hcl
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
