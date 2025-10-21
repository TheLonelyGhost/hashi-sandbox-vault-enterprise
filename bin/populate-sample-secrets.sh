#!/usr/bin/env bash
set -euo pipefail

vault kv put -mount=kv/my-thing class/agent/fizz lorem=ipsum
vault kv put -mount=kv/my-thing class/supervisor/buzz dolor=sit

vault kv put -mount=kv/my-thing clearance/top-secret/alice my-key=my-value
vault kv put -mount=kv/my-thing clearance/confidential/bob my-other-key=your-value
