resource "vault_generic_endpoint" "audit_logs" {
  path         = "sys/audit/stdout"
  disable_read = true

  data_json = jsonencode(
    {
      type                 = "file"
      description          = "Logs to stdout"
      elide_list_responses = true

      options = {
        file_path = "stdout"
      }

      log_raw = true
    }
  )
}

resource "vault_generic_endpoint" "audit_log_file" {
  path         = "sys/audit/file"
  disable_read = true

  data_json = jsonencode({
    type                 = "file"
    description          = "Logs to file"
    elide_list_responses = true

    options = {
      file_path = "/var/log/vault/audit.log"
    }

    log_raw = true
  })
}
