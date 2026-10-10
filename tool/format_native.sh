#!/usr/bin/env bash
# Formats the plugins' and the example's native code, or with --check fails
# when it isn't formatted:
# - Kotlin with ktlint (rules in .editorconfig), downloaded once into
#   .dart_tool/ at a pinned version and checksum;
# - Swift with Xcode's swift-format (rules in .swift-format), macOS only.
# Pigeon's generated files and the example's custom renderer samples (ported
# unchanged from Prebid's test apps) are left alone.
#
#   tool/format_native.sh [--check] [kotlin|swift]   (both by default)
set -euo pipefail
cd "$(dirname "$0")/.."

check=false
if [ "${1:-}" = --check ]; then
  check=true
  shift
fi
languages=${1:-kotlin swift}

ktlint_version=1.8.0
ktlint_sha256=a3fd620207d5c40da6ca789b95e7f823c54e854b7fade7f613e91096a3706d75

kotlin_files() {
  git ls-files 'packages/*/android/src/*.kt' 'packages/*/android/*.kts' \
    'example/android/*.kt' 'example/android/*.kts' |
    grep -v -e '\.g\.kt$' -e '/SampleCustomRenderer'
}

swift_files() {
  git ls-files 'packages/*/ios/*.swift' 'example/ios/Runner/*.swift' \
    'example/ios/RunnerTests/*.swift' |
    grep -v -e '\.g\.swift$' -e 'GeneratedPluginRegistrant' -e '/CustomRenderer/'
}

ktlint() {
  local bin=.dart_tool/ktlint-$ktlint_version
  if [ ! -x "$bin" ]; then
    mkdir -p .dart_tool
    curl -fsSL -o "$bin.download" \
      "https://github.com/ktlint/ktlint/releases/download/$ktlint_version/ktlint"
    echo "$ktlint_sha256  $bin.download" | shasum -a 256 -c - >/dev/null ||
      { echo "ktlint: checksum mismatch" >&2; rm -f "$bin.download"; exit 1; }
    chmod +x "$bin.download"
    mv "$bin.download" "$bin"
  fi
  "$bin" "$@"
}

# No file name has a space, so the lists are split on whitespace (bash 3,
# macOS's, has no mapfile).
status=0
for language in $languages; do
  case $language in
    kotlin)
      # shellcheck disable=SC2046
      if $check; then
        ktlint --relative $(kotlin_files) ||
          { echo "Kotlin isn't formatted: run tool/format_native.sh kotlin" >&2; status=1; }
      else
        ktlint --format --relative $(kotlin_files) || status=1
      fi
      ;;
    swift)
      if ! xcrun --find swift-format >/dev/null 2>&1; then
        echo "swift-format needs Xcode (macOS); skipping Swift" >&2
        continue
      fi
      # shellcheck disable=SC2046
      if $check; then
        xcrun swift-format lint --strict $(swift_files) ||
          { echo "Swift isn't formatted: run tool/format_native.sh swift" >&2; status=1; }
      else
        xcrun swift-format format --in-place $(swift_files)
        xcrun swift-format lint --strict $(swift_files) || status=1
      fi
      ;;
    *)
      echo "unknown language: $language (kotlin or swift)" >&2
      exit 2
      ;;
  esac
done
exit $status
