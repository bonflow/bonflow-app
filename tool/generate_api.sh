#!/usr/bin/env bash
# Generates the Dart API client (packages/bonflow_api) from the server's OpenAPI spec.
#
# Usage: tool/generate_api.sh <spec>
#   <spec>  path or URL of openapi.json, e.g. a running server:
#           tool/generate_api.sh http://localhost:8080/v3/api-docs
#           or the `openapi` artifact published by bonflow-server CI.
set -euo pipefail

spec="${1:?usage: tool/generate_api.sh <path-or-url-of-openapi.json>}"
cd "$(dirname "$0")/.."

rm -rf packages/bonflow_api
npx --yes @openapitools/openapi-generator-cli generate \
  -g dart-dio \
  -i "$spec" \
  -o packages/bonflow_api \
  -c openapi-generator-config.yaml

(cd packages/bonflow_api && dart run build_runner build --delete-conflicting-outputs)

echo "Done. Now enable the bonflow_api path dependency in pubspec.yaml and run 'flutter pub get'."
