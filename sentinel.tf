resource "vault_egp_policy" "no_entityless_tokens" {
  name              = "no-entityless-tokens"
  paths             = ["*"]
  enforcement_level = "soft-mandatory"

  policy = file("${path.module}/sentinel/no-entityless-tokens.egp.sentinel")
}
