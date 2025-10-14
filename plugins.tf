# resource "vault_plugin" "ldap" {
#   type    = "secret"
#   name    = "custom-openldap"
#   command = "vault-plugin-secrets-openldap"
#   version = "v5.0.0" # Some random version string that doesn't conflict
#   sha256  = filesha256("${path.module}/plugins/vault-plugin-secrets-openldap")
# }
# 
# resource "vault_mount" "ldap" {
#   type = vault_plugin.ldap.name
#   path = "ldap"
# }
