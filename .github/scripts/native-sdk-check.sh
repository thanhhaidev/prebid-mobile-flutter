#!/usr/bin/env bash
# Compares the newest Prebid Mobile releases (Maven Central for Android,
# CocoaPods trunk for iOS) with website/src/data/compatibility.json, and opens
# or updates a GitHub issue when a package is behind.
#
#   .github/scripts/native-sdk-check.sh            report, and open/update the issue (needs gh + GH_TOKEN)
#   .github/scripts/native-sdk-check.sh --dry-run  print the report only
set -euo pipefail

cd "$(dirname "$0")/../.."
dry_run=false
[[ "${1:-}" == "--dry-run" ]] && dry_run=true

compat=website/src/data/compatibility.json
label=native-sdk-update

# Newest stable version on Maven Central (`release` skips snapshots).
maven_latest() {
  local path=${1//.//}
  path=${path/://}
  curl -fsSL "https://repo1.maven.org/maven2/${path}/maven-metadata.xml" |
    sed -n 's:.*<release>\(.*\)</release>.*:\1:p'
}

# Newest stable version on CocoaPods trunk (no pre-release suffix).
pod_latest() {
  curl -fsSL "https://trunk.cocoapods.org/api/v1/pods/$1" |
    jq -r '.versions[].name' | grep -E '^[0-9]+(\.[0-9]+)*$' | sort -V | tail -1
}

# True when $2 is a newer version than $1.
is_newer() {
  [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" == "$2" ]]
}

rows=()
behind=()
for name in $(jq -r '.packages | keys_unsorted[]' "$compat"); do
  artifact=$(jq -r ".packages.\"$name\".android" "$compat")
  pod=$(jq -r ".packages.\"$name\".ios" "$compat")
  android=$(jq -r ".packages.\"$name\".releases[0].prebidAndroid" "$compat")
  ios=$(jq -r ".packages.\"$name\".releases[0].prebidIos.min" "$compat")
  latest_android=$(maven_latest "$artifact")
  latest_ios=$(pod_latest "$pod")

  mark_android=$android
  if is_newer "$android" "$latest_android"; then
    mark_android="$android → **$latest_android**"
    behind+=("Android $latest_android")
  fi
  mark_ios=$ios
  if is_newer "$ios" "$latest_ios"; then
    mark_ios="$ios → **$latest_ios**"
    behind+=("iOS $latest_ios")
  fi
  rows+=("| \`$name\` | \`$artifact\` $mark_android | \`$pod\` $mark_ios |")
done

table=$(printf '%s\n' "| Package | Android | iOS |" "| --- | --- | --- |" "${rows[@]}")
echo "$table"

if [[ ${#behind[@]} -eq 0 ]]; then
  echo "All packages use the newest Prebid Mobile releases."
  exit 0
fi

# One title per set of new versions, e.g. "Android 3.5.0, iOS 3.5.0".
versions=$(printf '%s\n' "${behind[@]}" | sort -u | paste -sd ',' - | sed 's/,/, /g')
title="Prebid Mobile update available: $versions"
body=$(cat <<BODY
New Prebid Mobile SDK releases are available (current → **newest**):

$table

Release notes: [Android](https://github.com/prebid/prebid-mobile-android/releases) · [iOS](https://github.com/prebid/prebid-mobile-ios/releases)

Prebid publishes the adapters and event handlers with the core SDK; update
every package to the same version once all of them are out.

### Checklist

- [ ] Read the release notes for breaking changes and new APIs worth exposing
- [ ] \`packages/*/android/build.gradle.kts\`: the \`org.prebid:*\` versions
- [ ] \`packages/*/ios/*.podspec\` and \`packages/*/ios/*/Package.swift\`: the Prebid iOS minimum
- [ ] \`website/src/data/compatibility.json\`: a new entry per package, then \`dart run melos run compatibility\`
- [ ] Bump the package versions and add CHANGELOG entries
- [ ] Run the example on Android and iOS

_Opened by the [native SDK check](../actions/workflows/native-sdk-check.yml); it updates this issue while it stays open._
BODY
)

if $dry_run; then
  echo
  echo "Would open: $title"
  exit 0
fi

gh label create "$label" --color F67725 \
  --description "A new native Prebid Mobile SDK is available" --force >/dev/null
existing=$(gh issue list --label "$label" --state open --json number --jq '.[0].number // empty')
if [[ -n "$existing" ]]; then
  gh issue edit "$existing" --title "$title" --body "$body" >/dev/null
  echo "Updated issue #$existing: $title"
else
  gh issue create --title "$title" --body "$body" --label "$label"
fi
