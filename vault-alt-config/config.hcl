ui           = true
cluster_addr = "https://127.0.0.1:8301"
api_addr     = "http://127.0.0.1:8300"

disable_mlock = true

storage "raft" {
  path = "/vault/file"
}

listener "tcp" {
  address     = "0.0.0.0:8300"
  tls_disable = true
}

cluster_name = "my-unseal-sandbox"

default_lease_ttl = "168h"
max_lease_ttl     = "720h"
