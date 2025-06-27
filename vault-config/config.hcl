ui           = true
cluster_addr = "https://127.0.0.1:8200"
api_addr     = "http://127.0.0.1:8200"

storage "raft" {
  path = "/vault/file"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true

  telemetry {
    unauthenticated_metrics_access = true
  }
}

cluster_name = "my-sandbox"

default_lease_ttl = "168h"
max_lease_ttl     = "720h"

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}
