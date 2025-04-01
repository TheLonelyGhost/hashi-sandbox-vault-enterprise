terraform {
  required_version = "~> 1.9"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.3"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    vaultstarter = {
      source  = "andrei-funaru/vault-starter"
      version = "~> 0.2.4"
    }
  }
}

provider "vaultstarter" {
  vault_addr = "http://127.0.0.1:8200"
}

resource "vaultstarter_init" "base" {
  secret_shares    = 3
  secret_threshold = 2
}
resource "vaultstarter_unseal" "base" {
  secret_shares    = vaultstarter_init.base.secret_shares
  secret_threshold = vaultstarter_init.base.secret_threshold
  keys             = vaultstarter_init.base.keys
}

resource "null_resource" "root_token" {
  triggers = {
    root_token = vaultstarter_init.base.root_token
  }

  depends_on = [vaultstarter_unseal.base]
}

provider "vault" {
  address = "http://127.0.0.1:8200"
  token   = null_resource.root_token.triggers.root_token
}
