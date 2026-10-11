#!/usr/bin/env bash
# Analyzes and tests the companion packages against the oldest core release
# they accept, the lower bound of their `prebid_mobile_sdk: ^x.y.z`, instead
# of the core in the checkout. The workspace resolves the core locally, so a
# companion that uses a core API not released yet would otherwise pass every
# check and publish a version no app can compile (ADR-0006).
#
# The core comes from its release tag, swapped into a temporary worktree of
# HEAD: uncommitted changes are not checked.
#
#   tool/check_released_core.sh [--require-release] [package ...]
#                                                  (default: all companions)
#
# A lower bound with no `prebid_mobile_sdk-v<version>` tag yet (the core
# release is part of the same change) is skipped with a warning, unless
# --require-release is given, as the release workflow does: a companion can't
# be published before the core it needs.
set -euo pipefail

cd "$(dirname "$0")/.."
require=false
if [[ ${1:-} == --require-release ]]; then
  require=true
  shift
fi
packages=("$@")
[[ ${#packages[@]} -eq 0 ]] && packages=(prebid_mobile_sdk_gam prebid_mobile_sdk_admob prebid_mobile_sdk_max)

work=$(mktemp -d)
tree=$work/tree
cleanup() {
  git worktree remove --force "$tree" 2> /dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT
git worktree add --quiet --detach "$tree" HEAD

status=0
for package in "${packages[@]}"; do
  lower=$(sed -n 's/^  prebid_mobile_sdk: *\^\{0,1\}\([0-9][^ ]*\).*/\1/p' "packages/$package/pubspec.yaml")
  [[ -n $lower ]] || { echo "released-core: no prebid_mobile_sdk constraint in $package" >&2; exit 1; }
  tag=prebid_mobile_sdk-v$lower
  # CI checks out without tags.
  git rev-parse --quiet --verify "refs/tags/$tag" > /dev/null ||
    git fetch --quiet --depth=1 origin tag "$tag" 2> /dev/null || true
  if ! git rev-parse --quiet --verify "refs/tags/$tag" > /dev/null; then
    if $require; then
      echo "released-core: $package needs prebid_mobile_sdk $lower, which has no $tag tag; release the core first" >&2
      status=1
    else
      echo "released-core: skipping $package (no $tag tag yet; the release workflow requires it)" >&2
    fi
    continue
  fi

  echo "released-core: $package against prebid_mobile_sdk $lower"
  rm -rf "$tree/packages/prebid_mobile_sdk"
  git -C "$tree" checkout --quiet "$tag" -- packages/prebid_mobile_sdk
  if ! (cd "$tree" && flutter pub get > /dev/null &&
    cd "packages/$package" && flutter analyze --no-pub && flutter test --no-pub); then
    echo "released-core: $package fails against prebid_mobile_sdk $lower; raise its constraint and release the core first" >&2
    status=1
  fi
done
exit "$status"
