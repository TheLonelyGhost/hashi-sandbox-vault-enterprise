resource "vault_mount" "pki_root" {
  path = "pki/temp-root"
  type = "pki"

  description = "TEMP PKI root CA"
}

resource "vault_pki_secret_backend_root_cert" "root" {
  backend = vault_mount.pki_root.path

  type                 = "internal"
  ttl                  = format("%s", 10 * 365 * 24 * 60 * 60)
  format               = "pem"
  private_key_format   = "der"
  key_type             = "rsa"
  key_bits             = 4096
  exclude_cn_from_sans = true

  common_name  = "Temp Root CA"
  organization = "Acme Corp"
}

resource "vault_pki_secret_backend_root_sign_intermediate" "trusted" {
  backend = vault_mount.pki_root.path

  ttl = format("%s", 5 * 365 * 24 * 60 * 60) # 5 years

  issuer_ref   = vault_pki_secret_backend_root_cert.root.issuer_id
  csr          = vault_pki_secret_backend_intermediate_cert_request.trusted.csr
  common_name  = vault_pki_secret_backend_intermediate_cert_request.trusted.common_name
  organization = vault_pki_secret_backend_intermediate_cert_request.trusted.organization
  country      = vault_pki_secret_backend_intermediate_cert_request.trusted.country
  key_usage    = vault_pki_secret_backend_intermediate_cert_request.trusted.key_usage

  permitted_dns_domains = ["*.example.com", "example.com"]
}


resource "vault_pki_secret_backend_root_sign_intermediate" "untrusted" {
  backend = vault_mount.pki_root.path

  ttl = format("%s", 5 * 365 * 24 * 60 * 60) # 5 years

  issuer_ref   = vault_pki_secret_backend_root_cert.root.issuer_id
  csr          = vault_pki_secret_backend_intermediate_cert_request.untrusted.csr
  common_name  = vault_pki_secret_backend_intermediate_cert_request.untrusted.common_name
  organization = vault_pki_secret_backend_intermediate_cert_request.untrusted.organization
  country      = vault_pki_secret_backend_intermediate_cert_request.untrusted.country
  key_usage    = vault_pki_secret_backend_intermediate_cert_request.untrusted.key_usage

  permitted_dns_domains = ["*.localhost", "localhost"]
}
