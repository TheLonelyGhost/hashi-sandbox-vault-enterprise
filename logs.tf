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
