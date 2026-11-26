#!/usr/bin/env bash
# Updates the OpenAPI snapshot the contract test (test/contract) runs against.
#
# Usage: tool/update_contract.sh [tag]   (default: latest release of bonflow-server)
set -euo pipefail
cd "$(dirname "$0")/.."

tag="${1:-latest}"
if [ "$tag" = latest ]; then
  tag="$(curl -fsSL https://api.github.com/repos/bonflow/bonflow-server/releases/latest | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')"
fi
curl -fsSL -o test/contract/openapi.json \
  "https://github.com/bonflow/bonflow-server/releases/download/${tag}/openapi-${tag}.json"
echo "Contract snapshot is now bonflow-server ${tag}. Run 'flutter test test/contract'."
