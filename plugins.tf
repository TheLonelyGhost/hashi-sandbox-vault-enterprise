resource "vault_plugin" "ldap" {
  type    = "secret"
  name    = "custom-openldap"
  command = "vault-plugin-secrets-openldap"
  version = "v5.0.0" # Some random version string that doesn't conflict
  sha256  = filesha256("${path.module}/plugins/vault-plugin-secrets-openldap")
}

resource "vault_mount" "ldap" {
  type = vault_plugin.ldap.name
  path = "ldap"
}

resource "vault_generic_endpoint" "ldap_config" {
  path = "${vault_mount.ldap.path}/config"

  ignore_absent_fields = true
  data_json = jsonencode({
    binddn                           = "cn=admin,dc=planetexpress,dc=com"
    bindpass                         = "GoodNewsEveryone"
    url                              = "ldap://openldap:10389"
    schema                           = "openldap"
    userdn                           = "dc=planetexpress,dc=com"
    skip_static_role_import_rotation = true
    disable_automated_rotation       = true
  })
}

resource "vault_ldap_secret_backend_static_role" "example" {
  mount = vault_mount.ldap.path

  username  = "PLANET\\Hubert J. Farnsworth"
  dn        = "cn=Hubert J. Farnsworth,ou=people,dc=planetexpress,dc=com"
  role_name = "professor"

  rotation_period = 3600

  depends_on = [vault_generic_endpoint.ldap_config]
}
