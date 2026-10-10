import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';

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
    final i = ChannelHarness('prebid_mobile_sdk_gam/interstitial');
    await PrebidGamInterstitialAd(
      configId: 'c',
      gamAdUnitId: 'u',
      impOrtbConfig: _ortb,
    ).loadAd();
    expect(i.argsOf('load')['impOrtbConfig'], _ortb);

    final r = ChannelHarness('prebid_mobile_sdk_gam/rewarded');
    await PrebidGamRewardedAd(
      configId: 'c',
      gamAdUnitId: 'u',
      impOrtbConfig: _ortb,
    ).loadAd();
    expect(r.argsOf('load')['impOrtbConfig'], _ortb);
  });

  testWidgets('banner sends adPosition', (tester) async {
    final views = PlatformViewHarness('prebid_mobile_sdk_gam/banner');
    addTearDown(views.dispose);
    await tester.pumpWidget(
      _host(
        const PrebidGamBannerAd(
          configId: 'c',
          gamAdUnitId: 'u',
          width: 320,
          height: 50,
          adPosition: PrebidAdPosition.footer,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(views.creationParams?['adPosition'], 5);
  }, variant: android);

  testWidgets('native sends context, subtype and placement', (tester) async {
    final views = PlatformViewHarness('prebid_mobile_sdk_gam/native');
    addTearDown(views.dispose);
    await tester.pumpWidget(
      _host(
        const PrebidGamNativeAd(
          configId: 'c',
          gamAdUnitId: 'u',
          nativeParameters: NativeParameters(
            context: NativeContextType.contentCentric,
            contextSubType: NativeContextSubType.article,
            placementType: NativePlacementType.inFeed,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(views.creationParams?['context'], 1);
    expect(views.creationParams?['contextSubType'], 11);
    expect(views.creationParams?['placementType'], 1);
  }, variant: android);

  test('fullscreen ads send pbAdSlot and globalOrtbConfig', () async {
    final i = ChannelHarness('prebid_mobile_sdk_gam/interstitial');
    await PrebidGamInterstitialAd(
      configId: 'c',
      gamAdUnitId: 'u',
      pbAdSlot: '/slot',
      globalOrtbConfig: '{"app":{}}',
    ).loadAd();
    expect(i.argsOf('load')['pbAdSlot'], '/slot');
    expect(i.argsOf('load')['globalOrtbConfig'], '{"app":{}}');

    final r = ChannelHarness('prebid_mobile_sdk_gam/rewarded');
    await PrebidGamRewardedAd(
      configId: 'c',
      gamAdUnitId: 'u',
      pbAdSlot: '/slot',
      globalOrtbConfig: '{"app":{}}',
    ).loadAd();
    expect(r.argsOf('load')['pbAdSlot'], '/slot');
    expect(r.argsOf('load')['globalOrtbConfig'], '{"app":{}}');
  });

  testWidgets('banner sends pbAdSlot and globalOrtbConfig', (tester) async {
    final views = PlatformViewHarness('prebid_mobile_sdk_gam/banner');
    addTearDown(views.dispose);
    await tester.pumpWidget(
      _host(
        const PrebidGamBannerAd(
          configId: 'c',
          gamAdUnitId: 'u',
          width: 320,
          height: 50,
          pbAdSlot: '/slot',
          globalOrtbConfig: '{"app":{}}',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(views.creationParams?['pbAdSlot'], '/slot');
    expect(views.creationParams?['globalOrtbConfig'], '{"app":{}}');
  }, variant: android);

  testWidgets('native sends the request options', (tester) async {
    final views = PlatformViewHarness('prebid_mobile_sdk_gam/native');
    addTearDown(views.dispose);
    await tester.pumpWidget(
      _host(
        const PrebidGamNativeAd(
          configId: 'c',
          gamAdUnitId: 'u',
          globalOrtbConfig: '{"app":{}}',
          nativeParameters: NativeParameters(
            placementCount: 2,
            sequence: 1,
            assetUrlSupport: true,
            dUrlSupport: false,
            privacy: true,
            ext: {'k': 1},
            assets: [
              NativeAsset.image(mimes: ['image/png'], ext: {'a': 1}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final p = views.creationParams;
    expect(p?['placementCount'], 2);
    expect(p?['sequence'], 1);
    expect(p?['assetUrlSupport'], isTrue);
    expect(p?['dUrlSupport'], isFalse);
    expect(p?['privacy'], isTrue);
    expect(p?['ext'], '{"k":1}');
    expect(p?['globalOrtbConfig'], '{"app":{}}');
    final asset = (p?['assets'] as List).single as Map;
    expect(asset['imageMimes'], ['image/png']);
    expect(asset['ext'], '{"a":1}');
  }, variant: android);
}
