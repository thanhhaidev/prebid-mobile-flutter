import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import 'channel_harness.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox(width: 400, child: Align(child: child)),
  ),
);

const _revenue = {
  'revenue': 0.0125,
  'revenuePrecision': 'exact',
  'networkName': 'Prebid',
  'placement': 'home',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  tearDown(() => PrebidMax.debugDropBidProbability = 0);

  group('PrebidMaxBannerAd', () {
    testWidgets('sends refresh interval and additional sizes', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_max/banner');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(
          const PrebidMaxBannerAd(
            configId: 'c',
            maxAdUnitId: 'u',
            width: 320,
            height: 50,
            refreshIntervalSeconds: 30,
            additionalSizes: [Size(728, 90)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(views.creationParams, {
        'configId': 'c',
        'maxAdUnitId': 'u',
        'width': 320,
        'height': 50,
        'autoLoad': true,
        'additionalSizes': [728, 90],
        'refreshIntervalSeconds': 30,
      });
    }, variant: android);

    testWidgets('sends ad formats and video parameters', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_max/banner');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(
          const PrebidMaxBannerAd(
            configId: 'c',
            maxAdUnitId: 'u',
            width: 300,
            height: 250,
            adFormats: {PrebidAdFormat.banner, PrebidAdFormat.video},
            videoParameters: VideoParameters(
              mimes: ['video/mp4'],
              plcmt: VideoPlcmt.accompanyingContent,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(views.creationParams?['adFormats'], ['banner', 'video']);
      expect(views.creationParams?['videoParameters'], {
        'mimes': ['video/mp4'],
        'plcmt': 2,
      });
    }, variant: android);

    testWidgets('adaptive spans the available width and adopts the height', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_max/banner');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(
          const PrebidMaxBannerAd(
            configId: 'c',
            maxAdUnitId: 'u',
            width: 320,
            height: 50,
            adaptive: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(views.creationParams?['adaptive'], isTrue);
      expect(views.creationParams?['adaptiveWidth'], 400);
      final banner = find.byType(PrebidMaxBannerAd);
      expect(tester.getSize(banner), const Size(400, 50));
      await views.emit('onAdSize', {'width': 400.0, 'height': 60.0});
      await tester.pump();
      expect(tester.getSize(banner), const Size(400, 60));
    }, variant: android);

    testWidgets('an adaptive MREC keeps its fixed size', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_max/banner');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(
          const PrebidMaxBannerAd(
            configId: 'c',
            maxAdUnitId: 'u',
            width: 300,
            height: 250,
            adaptive: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(views.creationParams?.containsKey('adaptiveWidth'), isFalse);
      expect(
        tester.getSize(find.byType(PrebidMaxBannerAd)),
        const Size(300, 250),
      );
    }, variant: android);

    testWidgets(
      'MAX listener gets expand, collapse, display failure, revenue',
      (tester) async {
        final views = PlatformViewHarness('prebid_mobile_sdk_max/banner');
        addTearDown(views.dispose);
        final fired = <String>[];
        PrebidMaxAdRevenue? revenue;
        await tester.pumpWidget(
          _host(
            PrebidMaxBannerAd(
              configId: 'c',
              maxAdUnitId: 'u',
              width: 320,
              height: 50,
              listener: PrebidMaxBannerAdListener(
                onAdFailed: (e) => fired.add('failed:$e'),
                onAdImpression: () => fired.add('impression'),
                onAdExpanded: () => fired.add('expanded'),
                onAdCollapsed: () => fired.add('collapsed'),
                onAdDisplayFailed: (e) => fired.add('displayFailed:$e'),
                onAdRevenuePaid: (r) {
                  fired.add('revenue');
                  revenue = r;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await views.emit('onAdExpanded');
        await views.emit('onAdCollapsed');
        await views.emit('onAdDisplayFailed', 'boom');
        await views.emit('onAdImpression');
        await views.emit('onAdRevenuePaid', _revenue);
        expect(fired, [
          'expanded',
          'collapsed',
          'failed:boom',
          'displayFailed:boom',
          'impression',
          'revenue',
        ]);
        expect(revenue?.revenue, 0.0125);
        expect(revenue?.revenuePrecision, 'exact');
        expect(revenue?.networkName, 'Prebid');
        expect(revenue?.placement, 'home');
      },
      variant: android,
    );

    testWidgets('a plain listener gets display failures as onAdFailed', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_max/banner');
      addTearDown(views.dispose);
      final fired = <String>[];
      await tester.pumpWidget(
        _host(
          PrebidMaxBannerAd(
            configId: 'c',
            maxAdUnitId: 'u',
            width: 320,
            height: 50,
            listener: PrebidBannerAdListener(
              onAdFailed: (e) => fired.add('failed:$e'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await views.emit('onAdDisplayFailed', 'boom');
      await views.emit('onAdExpanded');
      await views.emit('onAdRevenuePaid', _revenue);
      expect(fired, ['failed:boom']);
    }, variant: android);

    testWidgets('sends the drop-bid probability read at creation', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_max/banner');
      addTearDown(views.dispose);
      PrebidMax.debugDropBidProbability = 0.5;
      await tester.pumpWidget(
        _host(
          const PrebidMaxBannerAd(
            configId: 'c',
            maxAdUnitId: 'u',
            width: 320,
            height: 50,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(views.creationParams?['debugDropBidProbability'], 0.5);
    }, variant: android);
  });

  testWidgets('native listener gets revenue', (tester) async {
    final views = PlatformViewHarness('prebid_mobile_sdk_max/native');
    addTearDown(views.dispose);
    PrebidMaxAdRevenue? revenue;
    await tester.pumpWidget(
      _host(
        PrebidMaxNativeAd(
          configId: 'c',
          maxAdUnitId: 'u',
          listener: PrebidMaxNativeAdListener(
            onAdRevenuePaid: (r) => revenue = r,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await views.emit('onAdRevenuePaid', {'revenue': 1});
    expect(revenue?.revenue, 1.0);
    expect(revenue?.revenuePrecision, '');
    expect(revenue?.networkName, '');
    expect(revenue?.placement, isNull);
  }, variant: android);

  group('fullscreen', () {
    test('interstitial sends adFormats and routes revenue', () async {
      final h = ChannelHarness('prebid_mobile_sdk_max/interstitial');
      final revenues = <double>[];
      final ad = PrebidMaxInterstitialAd(
        configId: 'c',
        maxAdUnitId: 'u',
        adFormats: const {PrebidAdFormat.banner, PrebidAdFormat.video},
        listener: PrebidMaxInterstitialAdListener(
          onAdRevenuePaid: (r) => revenues.add(r.revenue),
        ),
      );
      await ad.loadAd();
      final args = h.argsOf('load');
      expect(args['adFormats'], ['banner', 'video']);
      expect(args['isVideo'], isFalse);
      expect(args.containsKey('debugDropBidProbability'), isFalse);
      await h.emit('onAdRevenuePaid', args['adId'] as int, _revenue);
      expect(revenues, [0.0125]);
    });

    test('rewarded routes revenue to a MAX listener only', () async {
      final h = ChannelHarness('prebid_mobile_sdk_max/rewarded');
      final revenues = <String>[];
      final ad = PrebidMaxRewardedAd(
        configId: 'c',
        maxAdUnitId: 'u',
        listener: PrebidMaxRewardedAdListener(
          onAdRevenuePaid: (r) => revenues.add(r.networkName),
        ),
      );
      await ad.loadAd();
      await h.emit(
        'onAdRevenuePaid',
        h.argsOf('load')['adId'] as int,
        _revenue,
      );
      expect(revenues, ['Prebid']);

      final plain = PrebidMaxRewardedAd(
        configId: 'c',
        maxAdUnitId: 'u2',
        listener: const PrebidRewardedAdListener(),
      );
      await plain.loadAd();
      // Ignored without error.
      await h.emit(
        'onAdRevenuePaid',
        h.argsOf('load')['adId'] as int,
        _revenue,
      );
      expect(revenues, ['Prebid']);
    });

    test('interstitial and rewarded send the drop-bid probability', () async {
      final i = ChannelHarness('prebid_mobile_sdk_max/interstitial');
      final r = ChannelHarness('prebid_mobile_sdk_max/rewarded');
      PrebidMax.debugDropBidProbability = 0.5;
      await PrebidMaxInterstitialAd(configId: 'c', maxAdUnitId: 'u').loadAd();
      await PrebidMaxRewardedAd(configId: 'c', maxAdUnitId: 'u').loadAd();
      expect(i.argsOf('load')['debugDropBidProbability'], 0.5);
      expect(r.argsOf('load')['debugDropBidProbability'], 0.5);

      PrebidMax.debugDropBidProbability = 2; // clamped
      await PrebidMaxInterstitialAd(configId: 'c', maxAdUnitId: 'u').loadAd();
      expect(i.argsOf('load')['debugDropBidProbability'], 1.0);
    });
  });

  test('a revenue reads well in logs', () {
    expect(
      const PrebidMaxAdRevenue(
        revenue: 0.012,
        revenuePrecision: 'exact',
        networkName: 'Prebid',
        placement: 'home',
      ).toString(),
      'PrebidMaxAdRevenue(revenue: 0.012, precision: exact, network: Prebid, '
      'placement: home)',
    );
  });
}
