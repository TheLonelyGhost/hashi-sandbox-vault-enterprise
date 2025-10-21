# Vault Sandbox

## Prerequisites

- [`task` runner](https://taskfile.dev)
- Go (v1.25+ preferred) -- required to easily generate client TLS cert
- Terraform CLI (v1.10 or higher)
- Docker Compose via `docker` binary (may be linked to a Podman backend)
- HashiCorp Vault Enterprise license
- Linux-like workstation (WSL is acceptable)

## Setup

Setup the following environment variables:

- `VAULT_LICENSE` -- containing the plaintext version of the Vault Enterprise license string

```bash
~/workspace $ task up
~/workspace $ source ./.env
~/workspace $ ./bin/populate-sample-secrets.sh

========== Secret Path ==========
kv/my-thing/data/class/agent/fizz

======= Metadata =======
Key                Value
---                -----
created_time       2025-10-21T15:27:13.447376123Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1
============= Secret Path =============
kv/my-thing/data/class/supervisor/buzz

======= Metadata =======
Key                Value
---                -----
created_time       2025-10-21T15:27:13.545103834Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1
=============== Secret Path ===============
kv/my-thing/data/clearance/top-secret/alice

======= Metadata =======
Key                Value
---                -----
created_time       2025-10-21T15:27:13.63061119Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1
=============== Secret Path ===============
kv/my-thing/data/clearance/confidential/bob

======= Metadata =======
Key                Value
---                -----
created_time       2025-10-21T15:27:13.718900413Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1
```

## DEMO

```bash
~/workspace $ ./bin/login-tls
No client TLS certificate materials found. Generating...
+ go run ./go/generate-client-cert.go
+ vault login -method=cert -path=tls -token-only name=sample
hvs.CAESIAr-XlXXXXXXXXXXXXXXXXXXXXXzAj6-yXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXE3S3MQojY

~/workspace $ export VAULT_TOKEN='hvs.CAESIAr-XlXXXXXXXXXXXXXXXXXXXXXzAj6-yXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXE3S3MQojY'

~/workspace $ vault kv get -mount=kv/my-thing clearance/confidential/bob

Error reading kv/my-thing/data/clearance/confidential/bob: Error making API request.

URL: GET https://127.0.0.1:8200/v1/kv/my-thing/data/clearance/confidential/bob
Code: 403. Errors:

* 1 error occurred:
	* permission denied

~/workspace $ vault kv metadata get -mount=kv/my-thing clearance/confidential/bob

================ Metadata Path ================
kv/my-thing/metadata/clearance/confidential/bob

========== Metadata ==========
Key                     Value
---                     -----
cas_required            false
created_time            2025-10-21T14:52:01.565760337Z
current_version         1
custom_metadata         <nil>
delete_version_after    0s
max_versions            0
oldest_version          0
updated_time            2025-10-21T15:27:13.718900413Z

====== Version 1 ======
Key              Value
---              -----
created_time     2025-10-21T15:27:13.718900413Z
deletion_time    n/a
destroyed        false

~/workspace $ vault kv get -mount=kv/my-thing clearance/top-secret/alice

=============== Secret Path ===============
kv/my-thing/data/clearance/top-secret/alice

======= Metadata =======
Key                Value
---                -----
created_time       2025-10-21T15:27:13.63061119Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1

===== Data =====
Key       Value
---       -----
my-key    my-value
```
