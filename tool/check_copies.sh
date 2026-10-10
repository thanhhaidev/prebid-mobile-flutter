#!/usr/bin/env bash
# Fails when a file the packages each keep a copy of drifts:
# - analysis_options.yaml: a published package can't include a file outside
#   itself. The example app skips public_member_api_docs (not a library).
# - test/channel_harness.dart of the companion packages: test code can't be
#   shared through the core package.
# - PrebidRequests.kt / PrebidRequests.swift of the companion packages: the
#   native parsing of the channel arguments, which each plugin compiles on its
#   own (the Kotlin copies differ only in their package line).
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
harness=packages/prebid_mobile_sdk_gam/test/channel_harness.dart
for file in packages/prebid_mobile_sdk_{admob,max}/test/channel_harness.dart; do
  if ! cmp -s "$harness" "$file"; then
    echo "copies: $file differs from $harness; keep the three identical" >&2
    status=1
  fi
done
kotlin=android/src/main/kotlin/io/github/thanhhaidev
requests() { sed '/^package /d' "$1"; }
reference=packages/prebid_mobile_sdk_gam/$kotlin/prebid_mobile_sdk_gam/PrebidRequests.kt
for pkg in admob max; do
  file=packages/prebid_mobile_sdk_$pkg/$kotlin/prebid_mobile_sdk_$pkg/PrebidRequests.kt
  if ! diff -q <(requests "$reference") <(requests "$file") >/dev/null; then
    echo "copies: $file differs from $reference; keep the three identical" >&2
    diff -u <(requests "$reference") <(requests "$file") >&2 || true
    status=1
  fi
done
reference=packages/prebid_mobile_sdk_gam/ios/prebid_mobile_sdk_gam/Sources/prebid_mobile_sdk_gam/PrebidRequests.swift
for pkg in admob max; do
  file=packages/prebid_mobile_sdk_$pkg/ios/prebid_mobile_sdk_$pkg/Sources/prebid_mobile_sdk_$pkg/PrebidRequests.swift
  if ! cmp -s "$reference" "$file"; then
    echo "copies: $file differs from $reference; keep the three identical" >&2
    diff -u "$reference" "$file" >&2 || true
    status=1
  fi
done
[ "$status" -eq 0 ] && echo "copies: lint rules, companion test harnesses and native request parsing in sync"
exit "$status"
