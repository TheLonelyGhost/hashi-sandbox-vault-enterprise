terraform {
  required_version = "~> 1.10"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
    vaultoperator = {
      source  = "rickardgranberg/vaultoperator"
      version = "~> 0.1.11"
    }
  }
}

provider "vaultoperator" {
  vault_addr        = var.vault_addr
  vault_skip_verify = true
}

resource "vaultoperator_init" "base" {
  recovery_shares    = 1
  recovery_threshold = 1
  secret_shares      = 0
  secret_threshold   = 0
}

resource "terraform_data" "root_token" {
  input = vaultoperator_init.base.root_token
}

provider "vault" {
  address      = var.vault_addr
  token        = terraform_data.root_token.input
  ca_cert_file = "${path.module}/vault-config/server.ca.crt"
}
