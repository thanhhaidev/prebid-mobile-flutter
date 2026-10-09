#!/usr/bin/env bash
# Scores every package with pana, the tool behind the pub.dev score, and fails
# when one gets less than the maximum.
#
# The companions depend on prebid_mobile_sdk from pub.dev, which pana resolves
# without the workspace. So the core package in this checkout is packed and
# served by a local pub server (tool/fake_pub_server.dart) that proxies
# everything else to pub.dev: the companions are scored against the core
# exactly as it would be published.
#
#   tool/score.sh [package ...]     (default: all packages)
set -euo pipefail

cd "$(dirname "$0")/.."
root=$PWD
port=${SCORE_PORT:-8787}
packages=("$@")
[[ ${#packages[@]} -eq 0 ]] && packages=(prebid_mobile_sdk prebid_mobile_sdk_gam prebid_mobile_sdk_admob prebid_mobile_sdk_max)

flutter_bin=$(command -v flutter)
flutter_sdk=$(cd "$(dirname "$flutter_bin")/.." && pwd -P)
command -v pana > /dev/null || dart pub global activate pana > /dev/null
export PATH="$PATH:$HOME/.pub-cache/bin"

work=$(mktemp -d)
trap 'kill "${server:-}" 2> /dev/null || true; rm -rf "$work"' EXIT

# Pack the core package with the files `pub publish` would include.
core=packages/prebid_mobile_sdk
(cd "$core" && git ls-files -co --exclude-standard . |
  while read -r f; do [[ -f $f ]] && echo "$f"; done > "$work/files.txt" &&
  tar -czf "$work/core.tar.gz" -T "$work/files.txt")

dart run tool/fake_pub_server.dart "$port" "$root/$core=$work/core.tar.gz" &
server=$!
for _ in $(seq 1 60); do
  curl -fsS "http://localhost:$port/api/packages/prebid_mobile_sdk" > /dev/null 2>&1 && break
  sleep 1
done

failed=()
for name in "${packages[@]}"; do
  echo "::group::pana $name"
  report="$work/$name.txt"
  pana --no-warning --hosted-url "http://localhost:$port" --flutter-sdk "$flutter_sdk" \
    --exit-code-threshold 0 "packages/$name" > "$report" 2>&1 || true
  sed -n '/^## /,$p' "$report"
  echo "::endgroup::"
  points=$(grep -E '^Points: ' "$report" || echo "Points: ?")
  echo "$name: $points"
  [[ $points == "Points: 160/160." ]] || failed+=("$name ($points)")
done

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "Below the maximum score: ${failed[*]}" >&2
  exit 1
fi
echo "All packages score 160/160."
