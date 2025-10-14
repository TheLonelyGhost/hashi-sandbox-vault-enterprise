ui           = true
cluster_addr = "https://127.0.0.1:8201"
api_addr     = "https://127.0.0.1:8200"

disable_mlock = true

storage "raft" {
  path = "/vault/file"
}

listener "tcp" {
  address = "0.0.0.0:8200"

  tls_cert_file = "/vault/config/server.bundle.crt"
  tls_key_file  = "/vault/config/server.pem"

  telemetry {
    unauthenticated_metrics_access = true
  }
}

cluster_name     = "my-sandbox"
plugin_directory = "/vault/plugins"

default_lease_ttl = "168h"
max_lease_ttl     = "720h"

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}
