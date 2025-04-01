resource "vault_namespace" "tester" {
  path = "marketing"
}

resource "vault_namespace" "subns" {
  path      = "buffalobills"
  namespace = vault_namespace.tester.path
}

resource "vault_namespace" "other" {
  path = "billing"
}

resource "vault_namespace" "other_subns" {
  path      = "buffalobills"
  namespace = vault_namespace.other.path
}
