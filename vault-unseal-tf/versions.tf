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
    vaultstarter = {
      source  = "andrei-funaru/vault-starter"
      version = "~> 0.2.4"
    }
  }
}

provider "vaultstarter" {
  vault_addr = var.vault_addr
}

resource "vaultstarter_init" "base" {
  secret_shares    = 1
  secret_threshold = 1
}
resource "vaultstarter_unseal" "base" {
  secret_shares    = vaultstarter_init.base.secret_shares
  secret_threshold = vaultstarter_init.base.secret_threshold
  keys             = vaultstarter_init.base.keys
}

resource "terraform_data" "root_token" {
  input = vaultstarter_init.base.root_token

  depends_on = [vaultstarter_unseal.base]
}

provider "vault" {
  address = var.vault_addr
  token   = terraform_data.root_token.input
}
