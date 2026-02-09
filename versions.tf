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
    # vaultoperator = {
    #   source  = "rickardgranberg/vaultoperator"
    #   version = "~> 0.1.11"
    # }
  }
}

locals {
  init = jsondecode(file("${path.module}/init.json"))
}

resource "terraform_data" "root_token" {
  input = local.init.root_token
}

provider "vault" {
  address      = var.vault_addr
  token        = terraform_data.root_token.input
  ca_cert_file = "${path.module}/vault-config/server.ca.crt"
}
