resource "vault_generic_endpoint" "audit_logs" {
  path         = "sys/audit/file"
  disable_read = true

  data_json = jsonencode(
    merge(
      {
        type                 = "file"
        description          = "File-based audit event sink that can be consumed by a log forwarder and is managed by logrotate"
        elide_list_responses = true

        options = {
          file_path = "/var/log/vault/audit.log"
          mode      = "0644"
        }
      },
      { log_raw = true }, # Only if local dev
    )
  )
}
