#!/usr/bin/env bash
# Checks the four packages the way an app gets them, in a fresh app outside
# the workspace (so none of the workspace's dev dependencies are resolved):
#
#   tool/check_consumer_app.sh test   compile and run a smoke test that uses
#                                     every public library, with the Flutter
#                                     on PATH (CI: the oldest supported one)
#   tool/check_consumer_app.sh spm    build the app for the iOS simulator
#                                     with Swift Package Manager only, no
#                                     CocoaPods (macOS)
#
# The example app can't do either: it needs newer SDKs for its own
# dependencies, and applovin_max has no Swift Package Manager support.
set -euo pipefail
cd "$(dirname "$0")/.."
root=$PWD
mode=${1:-}
[[ $mode == test || $mode == spm ]] || { echo "usage: $0 test|spm" >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
(cd "$work" && flutter create --platforms=ios --org io.github.thanhhaidev --empty consumer_app > /dev/null)
app=$work/consumer_app

dart_sdk=$(sed -n "s/^  sdk: *'\{0,1\}\([^']*\)'\{0,1\}$/\1/p" packages/prebid_mobile_sdk/pubspec.yaml | head -1)
{
  echo 'name: consumer_app'
  echo 'publish_to: none'
  echo 'environment:'
  echo "  sdk: '$dart_sdk'"
  echo 'dependencies:'
  echo '  flutter:'
  echo '    sdk: flutter'
  for package in prebid_mobile_sdk prebid_mobile_sdk_gam prebid_mobile_sdk_admob prebid_mobile_sdk_max; do
    echo "  $package:"
    echo "    path: $root/packages/$package"
  done
  # The companions ask for the core from pub.dev: use this checkout's.
  echo 'dependency_overrides:'
  echo '  prebid_mobile_sdk:'
  echo "    path: $root/packages/prebid_mobile_sdk"
  echo 'dev_dependencies:'
  echo '  flutter_test:'
  echo '    sdk: flutter'
  echo 'flutter:'
  echo '  config:'
  echo '    enable-swift-package-manager: true'
} > "$app/pubspec.yaml"

mkdir -p "$app/test"
cat > "$app/test/smoke_test.dart" << 'EOF'
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/companion.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every public library compiles and builds its ads', () {
    expect(
      const PrebidBannerAd(configId: 'c', width: 320, height: 50),
      isA<Widget>(),
    );
    expect(PrebidInterstitialAd(configId: 'c').isLoaded, isFalse);
    expect(
      const PrebidGamBannerAd(
        configId: 'c',
        gamAdUnitId: 'u',
        width: 320,
        height: 50,
      ),
      isA<Widget>(),
    );
    expect(
      const PrebidAdMobBannerAd(
        configId: 'c',
        adMobAdUnitId: 'u',
        width: 320,
        height: 50,
      ),
      isA<Widget>(),
    );
    expect(
      const PrebidMaxBannerAd(
        configId: 'c',
        maxAdUnitId: 'u',
        width: 320,
        height: 50,
      ),
      isA<Widget>(),
    );
    expect(impOrtbWithGpid(null, '/1/home'), '{"ext":{"gpid":"/1/home"}}');
  });
}
EOF

cd "$app"
flutter --version | head -1
flutter pub get > /dev/null
case $mode in
  test) flutter test ;;
  spm)
    flutter build ios --simulator --debug
    # Every plugin came through Swift Package Manager.
    [[ ! -e ios/Podfile ]] || { echo "consumer app: CocoaPods was used" >&2; exit 1; }
    ;;
esac
