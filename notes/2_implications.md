# Vault Event Notifications

## Implications for us

- Vault-aware applications can handle cache-invalidation nicer
  - Example: static role has its password rotated outside of schedule
- Less reliance on Vault Proxy (offers KV caching, unlike Vault Agent)
- Reactive model to updating cached, in-memory secrets
  - Other uses besides cache: Application's DEK changes, so start batch process
      to re-encrypt to new DEK
  - Lighter load on Vault?
- New best practice for Vault-aware applications?
