import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';

import 'channel_harness.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox(width: 400, child: Align(child: child)),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  tearDown(() => PrebidAdMob.debugDropBidProbability = 0);

  group('PrebidAdMobBannerAd', () {
    testWidgets('sends refresh interval and additional sizes', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_admob/banner');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(
          const PrebidAdMobBannerAd(
            configId: 'c',
            adMobAdUnitId: 'u',
            width: 320,
            height: 50,
            refreshIntervalSeconds: 30,
            additionalSizes: [Size(728, 90), Size(300, 250)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(views.creationParams, {
        'configId': 'c',
        'adMobAdUnitId': 'u',
        'width': 320,
        'height': 50,
        'autoLoad': true,
        'additionalSizes': [728, 90, 300, 250],
        'refreshIntervalSeconds': 30,
      });
      expect(
        tester.getSize(find.byType(PrebidAdMobBannerAd)),
        const Size(320, 50),
      );
    }, variant: android);

    testWidgets('adaptive spans the available width and adopts the height', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_admob/banner');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(
          const PrebidAdMobBannerAd(
            configId: 'c',
            adMobAdUnitId: 'u',
            width: 320,
            height: 50,
            adaptive: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(views.creationParams?['adaptive'], isTrue);
      expect(views.creationParams?['adaptiveWidth'], 400);
      final banner = find.byType(PrebidAdMobBannerAd);
      expect(tester.getSize(banner), const Size(400, 50));

      await views.emit('onAdSize', {'width': 400.0, 'height': 62.0});
      await tester.pump();
      expect(tester.getSize(banner), const Size(400, 62));
      expect(views.createdParams, hasLength(1)); // no re-creation
    }, variant: android);

    testWidgets('sends the drop-bid probability read at creation', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_admob/banner');
      addTearDown(views.dispose);
      PrebidAdMob.debugDropBidProbability = 0.5;
      Widget banner() => _host(
        const PrebidAdMobBannerAd(
          configId: 'c',
          adMobAdUnitId: 'u',
          width: 320,
          height: 50,
        ),
      );
      await tester.pumpWidget(banner());
      await tester.pumpAndSettle();
      expect(views.creationParams?['debugDropBidProbability'], 0.5);

      // A later change does not re-create the existing view.
      PrebidAdMob.debugDropBidProbability = 0;
      await tester.pumpWidget(banner());
      await tester.pumpAndSettle();
      expect(views.createdParams, hasLength(1));
    }, variant: android);
  });

  group('fullscreen', () {
    test('interstitial sends adFormats next to isVideo', () async {
      final h = ChannelHarness('prebid_mobile_sdk_admob/interstitial');
      await PrebidAdMobInterstitialAd(
        configId: 'c',
        adMobAdUnitId: 'u',
        adFormats: const {PrebidAdFormat.banner, PrebidAdFormat.video},
      ).loadAd();
      final args = h.argsOf('load');
      expect(args['adFormats'], ['banner', 'video']);
      expect(args['isVideo'], isFalse);
      expect(args.containsKey('debugDropBidProbability'), isFalse);

      await PrebidAdMobInterstitialAd(
        configId: 'c',
        adMobAdUnitId: 'u',
      ).loadAd();
      expect(h.argsOf('load').containsKey('adFormats'), isFalse);
    });

    test('interstitial and rewarded send the drop-bid probability', () async {
      final i = ChannelHarness('prebid_mobile_sdk_admob/interstitial');
      final r = ChannelHarness('prebid_mobile_sdk_admob/rewarded');
      PrebidAdMob.debugDropBidProbability = 0.5;
      await PrebidAdMobInterstitialAd(
        configId: 'c',
        adMobAdUnitId: 'u',
      ).loadAd();
      await PrebidAdMobRewardedAd(configId: 'c', adMobAdUnitId: 'u').loadAd();
      expect(i.argsOf('load')['debugDropBidProbability'], 0.5);
      expect(r.argsOf('load')['debugDropBidProbability'], 0.5);

      PrebidAdMob.debugDropBidProbability = 3; // clamped
      await PrebidAdMobRewardedAd(configId: 'c', adMobAdUnitId: 'u').loadAd();
      expect(r.argsOf('load')['debugDropBidProbability'], 1.0);

      PrebidAdMob.debugDropBidProbability = -1; // off
      await PrebidAdMobRewardedAd(configId: 'c', adMobAdUnitId: 'u').loadAd();
      expect(r.argsOf('load').containsKey('debugDropBidProbability'), isFalse);
    });
  });
}
