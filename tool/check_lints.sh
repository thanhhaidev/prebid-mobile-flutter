#!/usr/bin/env bash
# Fails when a package's lint rules drift from the core package's.
# Each published package carries its own analysis_options.yaml (it can't
# include a file outside itself), so the copies are compared here. The
# example app skips public_member_api_docs (it is not a library).
set -euo pipefail
cd "$(dirname "$0")/.."

rules() { sed -n '/^linter:/,$p' "$1" | grep -v 'public_member_api_docs'; }

reference=packages/prebid_mobile_sdk/analysis_options.yaml
status=0
for file in packages/*/analysis_options.yaml example/analysis_options.yaml; do
  if ! diff -u <(rules "$reference") <(rules "$file") >/dev/null; then
    echo "lints: $file differs from $reference:" >&2
    diff -u <(rules "$reference") <(rules "$file") >&2 || true
    status=1
  fi
done
for file in packages/*/analysis_options.yaml; do
  grep -q 'public_member_api_docs' "$file" ||
    { echo "lints: $file must enable public_member_api_docs" >&2; status=1; }
done
[ "$status" -eq 0 ] && echo "lints: every package uses the shared rule set"
exit "$status"
