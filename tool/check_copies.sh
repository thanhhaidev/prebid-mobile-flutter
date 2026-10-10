#!/usr/bin/env bash
# Fails when a file the packages each keep a copy of drifts:
# - analysis_options.yaml: a published package can't include a file outside
#   itself. The example app skips public_member_api_docs (not a library).
# - test/channel_harness.dart of the companion packages: test code can't be
#   shared through the core package.
# - the native code every companion package shares (the request parsing,
#   the fullscreen ad manager, the plugin helpers), which each plugin
#   compiles on its own (the Kotlin copies differ only in their package line),
#   with PrebidRequestsTest.kt, its JVM unit test (same rule), and
#   PrebidCommon, the native code the core and GAM packages share.
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
swift=ios/prebid_mobile_sdk_PKG/Sources/prebid_mobile_sdk_PKG
unpackaged() { sed '/^package /d' "$1"; }
for name in main/PrebidRequests.kt main/FullscreenAdManager.kt main/PrebidPlugin.kt \
  test/PrebidRequestsTest.kt; do
  set_dir=${name%%/*}
  name=${name#*/}
  dir=android/src/$set_dir/kotlin/io/github/thanhhaidev
  reference=packages/prebid_mobile_sdk_gam/$dir/prebid_mobile_sdk_gam/$name
  for pkg in admob max; do
    file=packages/prebid_mobile_sdk_$pkg/$dir/prebid_mobile_sdk_$pkg/$name
    if ! diff -q <(unpackaged "$reference") <(unpackaged "$file") >/dev/null; then
      echo "copies: $file differs from $reference; keep the three identical" >&2
      diff -u <(unpackaged "$reference") <(unpackaged "$file") >&2 || true
      status=1
    fi
  done
done
for name in PrebidRequests.swift FullscreenAdManager.swift PrebidPlugin.swift; do
  reference=packages/prebid_mobile_sdk_gam/${swift//PKG/gam}/$name
  for pkg in admob max; do
    file=packages/prebid_mobile_sdk_$pkg/${swift//PKG/$pkg}/$name
    if ! cmp -s "$reference" "$file"; then
      echo "copies: $file differs from $reference; keep the three identical" >&2
      diff -u "$reference" "$file" >&2 || true
      status=1
    fi
  done
done
core_common=packages/prebid_mobile_sdk/$kotlin/prebid_mobile_sdk/PrebidCommon.kt
gam_common=packages/prebid_mobile_sdk_gam/$kotlin/prebid_mobile_sdk_gam/PrebidCommon.kt
if ! diff -q <(unpackaged "$core_common") <(unpackaged "$gam_common") >/dev/null; then
  echo "copies: $gam_common differs from $core_common; keep the two identical" >&2
  diff -u <(unpackaged "$core_common") <(unpackaged "$gam_common") >&2 || true
  status=1
fi
core_common=packages/prebid_mobile_sdk/ios/prebid_mobile_sdk/Sources/prebid_mobile_sdk/PrebidCommon.swift
gam_common=packages/prebid_mobile_sdk_gam/${swift//PKG/gam}/PrebidCommon.swift
if ! cmp -s "$core_common" "$gam_common"; then
  echo "copies: $gam_common differs from $core_common; keep the two identical" >&2
  diff -u "$core_common" "$gam_common" >&2 || true
  status=1
fi
[ "$status" -eq 0 ] && echo "copies: lint rules, companion test harnesses and shared native code in sync"
exit "$status"
