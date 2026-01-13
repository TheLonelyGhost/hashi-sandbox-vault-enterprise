resource "vault_mount" "kv" {
  path = "kv/my-thing"
  type = "kv-v2"
}

resource "vault_database_secrets_mount" "pg" {
  path = "postgres"

  postgresql {
    name              = "my-example"
    username          = "mysupersecureuser"
    password          = "hunter2"
    connection_url    = "postgresql://{{username}}:{{password}}@postgres:5432/mydatabase"
    verify_connection = true

    allowed_roles = [
      "example",
    ]
  }
}

resource "vault_database_secret_backend_role" "pg-example" {
  name    = "example"
  backend = vault_database_secrets_mount.pg.path
  db_name = vault_database_secrets_mount.pg.postgresql[0].name
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
  ]
}
