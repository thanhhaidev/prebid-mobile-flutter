import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import 'channel_harness.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

const _ortb = '{"ext":{"gpid":"/1111/home"}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  test('interstitial and rewarded send impOrtbConfig', () async {
    final i = ChannelHarness('prebid_mobile_sdk_max/interstitial');
    await PrebidMaxInterstitialAd(
      configId: 'c',
      maxAdUnitId: 'u',
      impOrtbConfig: _ortb,
    ).loadAd();
    expect(i.argsOf('load')['impOrtbConfig'], _ortb);

    final r = ChannelHarness('prebid_mobile_sdk_max/rewarded');
    await PrebidMaxRewardedAd(
      configId: 'c',
      maxAdUnitId: 'u',
      impOrtbConfig: _ortb,
    ).loadAd();
    expect(r.argsOf('load')['impOrtbConfig'], _ortb);
  });

  testWidgets('banner sends adPosition', (tester) async {
    final views = PlatformViewHarness('prebid_mobile_sdk_max/banner');
    addTearDown(views.dispose);
    await tester.pumpWidget(
      _host(
        const PrebidMaxBannerAd(
          configId: 'c',
          maxAdUnitId: 'u',
          width: 320,
          height: 50,
          adPosition: PrebidAdPosition.footer,
          impOrtbConfig: _ortb,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(views.creationParams?['adPosition'], 5);
    expect(views.creationParams?['impOrtbConfig'], _ortb);
  }, variant: android);

  testWidgets('native sends context, subtype and placement', (tester) async {
    final views = PlatformViewHarness('prebid_mobile_sdk_max/native');
    addTearDown(views.dispose);
    await tester.pumpWidget(
      _host(
        const PrebidMaxNativeAd(
          configId: 'c',
          maxAdUnitId: 'u',
          context: NativeContextType.contentCentric,
          contextSubType: NativeContextSubType.article,
          placementType: NativePlacementType.inFeed,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(views.creationParams?['context'], 1);
    expect(views.creationParams?['contextSubType'], 11);
    expect(views.creationParams?['placementType'], 1);
  }, variant: android);
}
