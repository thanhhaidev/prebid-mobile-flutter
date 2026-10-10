import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

import 'fake_platform_views.dart';
import 'mock_host_api.mocks.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  group('rewarded', () {
    test('sends formats, video, global ORTB and tracks isLoaded', () async {
      final api = MockRewardedAdHostApi();
      PrebidRewardedAd.api = api;
      final ad = PrebidRewardedAd(
        configId: 'r',
        adFormats: const {PrebidAdFormat.video},
        videoParameters: const VideoParameters(
          mimes: ['video/mp4'],
          size: Size(640, 480),
        ),
        globalOrtbConfig: '{"app":{}}',
      );
      await ad.loadAd();
      final captured = verify(
        api.loadAd(any, 'r', captureAny, captureAny, any, captureAny, any, any),
      ).captured;
      expect(captured[0], ['video']);
      final video = captured[1] as VideoParametersConfig;
      expect([video.width, video.height], [640, 480]);
      expect(captured[2], '{"app":{}}');
      expect(ad.isLoaded, isFalse);
    });
  });

  test('VideoParameters.size reaches the companion map', () {
    const params = VideoParameters(mimes: ['video/mp4'], size: Size(400, 300));
    expect(params.toMap(), containsPair('width', 400));
    expect(params.toMap(), containsPair('height', 300));
  });

  group('getters', () {
    test('PrebidMobile reads the native values', () async {
      final api = MockPrebidMobileHostApi();
      PrebidMobile.api = api;
      when(api.getTimeoutMillis()).thenAnswer((_) async => 3000);
      when(api.getEidsPlacement()).thenAnswer((_) async => 'openRtb26');
      when(api.getStoredBidResponses()).thenAnswer((_) async => {'b': 'r'});
      expect(await PrebidMobile.getTimeoutMillis(), 3000);
      expect(
        await PrebidMobile.getEidsPlacement(),
        PrebidEidsPlacement.openRtb26,
      );
      expect(await PrebidMobile.getStoredBidResponses(), {'b': 'r'});
    });

    test('PrebidTargeting converts location and ext data', () async {
      final api = MockTargetingHostApi();
      PrebidTargeting.api = api;
      when(api.getUserLatLng()).thenAnswer((_) async => [1.5, 2.5]);
      when(api.getAppExtData()).thenAnswer(
        (_) async => {
          'k': ['v'],
        },
      );
      expect(await PrebidTargeting.getUserLatLng(), (1.5, 2.5));
      expect(await PrebidTargeting.getAppExtData(), {
        'k': ['v'],
      });
      when(api.getUserLatLng()).thenAnswer((_) async => null);
      expect(await PrebidTargeting.getUserLatLng(), isNull);
    });
  });

  group('settings added for parity', () {
    test(
      'PrebidMobile log listener, log level none, location updates',
      () async {
        final api = MockPrebidMobileHostApi();
        PrebidMobile.api = api;
        final logs = <(PrebidLogLevel, String)>[];
        await PrebidMobile.setLogListener((l, m) => logs.add((l, m)));
        verify(api.setLogListenerEnabled(true)).called(1);

        const codec = PrebidEventFlutterApi.pigeonChannelCodec;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        Future<void> log(
          int level,
          String message,
        ) => messenger.handlePlatformMessage(
          'dev.flutter.pigeon.prebid_mobile_sdk.PrebidEventFlutterApi.onLog',
          codec.encodeMessage([level, message]),
          (_) {},
        );
        await log(4, 'boom');
        await log(99, 'ignored');
        expect(logs, [(PrebidLogLevel.error, 'boom')]);

        await PrebidMobile.setLogListener(null);
        verify(api.setLogListenerEnabled(false)).called(1);
        await log(2, 'after');
        expect(logs, hasLength(1));

        await PrebidMobile.setLogLevel(PrebidLogLevel.none);
        verify(api.setLogLevel(6)).called(1);

        when(api.getLocationUpdatesEnabled()).thenAnswer((_) async => false);
        await PrebidMobile.setLocationUpdatesEnabled(false);
        verify(api.setLocationUpdatesEnabled(false)).called(1);
        expect(await PrebidMobile.getLocationUpdatesEnabled(), isFalse);
      },
    );

    test('PrebidTargeting parity calls', () async {
      final api = MockTargetingHostApi();
      PrebidTargeting.api = api;
      when(api.isAllowedAccessDeviceData()).thenAnswer((_) async => true);
      when(api.getAppKeywords()).thenAnswer((_) async => ['news']);
      when(api.getBundleName()).thenAnswer((_) async => 'com.prod');
      when(api.getSourceApp()).thenAnswer((_) async => '123');
      when(api.getItunesId()).thenAnswer((_) async => '456');
      expect(await PrebidTargeting.isAllowedAccessDeviceData(), isTrue);
      expect(await PrebidTargeting.getAppKeywords(), ['news']);
      await PrebidTargeting.setBundleName('com.prod');
      verify(api.setBundleName('com.prod')).called(1);
      expect(await PrebidTargeting.getBundleName(), 'com.prod');
      expect(await PrebidTargeting.getSourceApp(), '123');
      expect(await PrebidTargeting.getItunesId(), '456');
      await PrebidTargeting.clearUserLatLng();
      verify(api.clearUserLatLng()).called(1);
    });

    test('fullscreen ads send pbAdSlot', () async {
      final interstitial = MockInterstitialAdHostApi();
      PrebidInterstitialAd.api = interstitial;
      await PrebidInterstitialAd(configId: 'i', pbAdSlot: '/i').loadAd();
      verify(
        interstitial.loadAd(any, 'i', any, any, any, any, any, '/i'),
      ).called(1);

      final rewarded = MockRewardedAdHostApi();
      PrebidRewardedAd.api = rewarded;
      await PrebidRewardedAd(configId: 'r', pbAdSlot: '/r').loadAd();
      verify(
        rewarded.loadAd(any, 'r', any, any, any, any, any, '/r'),
      ).called(1);
    });

    test('generateInstreamUriForGam flattens the sizes', () async {
      final api = MockInstreamVideoAdHostApi();
      PrebidInstreamVideoAd.api = api;
      when(
        api.generateInstreamUriForGam(any, any, any),
      ).thenAnswer((_) async => 'https://pubads');
      final url = await PrebidInstreamVideoAd.generateInstreamUriForGam(
        gamAdUnitId: '/1/video',
        sizes: const [Size(640, 480)],
        targetingKeywords: const {'hb_pb': '1.00'},
      );
      expect(url, 'https://pubads');
      verify(
        api.generateInstreamUriForGam(
          '/1/video',
          [640, 480],
          {'hb_pb': '1.00'},
        ),
      ).called(1);
    });
  });

  group('Original API', () {
    late MockMultiformatAdHostApi api;

    setUp(() {
      api = MockMultiformatAdHostApi();
      PrebidMultiformatAd.api = api;
    });

    test('keeps exp, topBidFiltered and events in the bid response', () async {
      when(api.fetchDemand(any, any)).thenAnswer(
        (_) async => MultiformatBidResult(
          resultCode: 'prebidDemandFetchSuccess',
          exp: 300,
          topBidFiltered: true,
          events: {'ext.prebid.events.win': 'https://win'},
        ),
      );
      final unit = PrebidBannerAdUnit(
        configId: 'b',
        sizes: const [Size(300, 250)],
        gpid: '/1/home',
      );
      final response = await unit.fetchDemand();
      expect(response.exp, 300);
      expect(response.topBidFiltered, isTrue);
      expect(response.events, {'ext.prebid.events.win': 'https://win'});
      final config =
          verify(api.fetchDemand(any, captureAny)).captured.single
              as MultiformatAdRequestConfig;
      expect(config.gpid, '/1/home');
    });

    test('sends banner API and the interstitial minimum size', () async {
      when(api.fetchDemand(any, any)).thenAnswer(
        (_) async => MultiformatBidResult(resultCode: 'prebidDemandNoBids'),
      );
      await PrebidMultiformatAd(
        configId: 'm',
        bannerSizes: const [Size(320, 480)],
        isInterstitial: true,
        bannerApi: const [VideoApi.mraid2],
        interstitialMinSizePercentage: const Size(50, 70),
        supportSKOverlay: true,
      ).fetchDemand();
      final config =
          verify(api.fetchDemand(any, captureAny)).captured.single
              as MultiformatAdRequestConfig;
      expect(config.bannerApi, [VideoApi.mraid2.value]);
      expect(config.interstitialMinWidthPercentage, 50);
      expect(config.interstitialMinHeightPercentage, 70);
      expect(config.supportSKOverlay, isTrue);
    });

    test('sends pbAdSlot, ORTB configs and native options', () async {
      when(api.fetchDemand(any, any)).thenAnswer(
        (_) async => MultiformatBidResult(resultCode: 'prebidDemandNoBids'),
      );
      await PrebidNativeAdUnit(
        configId: 'n',
        assets: const [NativeAsset.title()],
        placementCount: 2,
        sequence: 1,
        assetUrlSupport: true,
        dUrlSupport: false,
        privacy: true,
        ext: const {'k': 1},
        pbAdSlot: '/slot',
        impOrtbConfig: '{"imp":1}',
        globalOrtbConfig: '{"app":{}}',
      ).fetchDemand();
      final config =
          verify(api.fetchDemand(any, captureAny)).captured.single
              as MultiformatAdRequestConfig;
      expect(config.pbAdSlot, '/slot');
      expect(config.impOrtbConfig, '{"imp":1}');
      expect(config.globalOrtbConfig, '{"app":{}}');
      final native = config.nativeConfig!;
      expect(native.placementCount, 2);
      expect(native.sequence, 1);
      expect(native.assetUrlSupport, isTrue);
      expect(native.dUrlSupport, isFalse);
      expect(native.privacy, isTrue);
      expect(native.ext, '{"k":1}');
    });

    test('an interstitial with a minimum size needs no banner size', () async {
      when(api.fetchDemand(any, any)).thenAnswer(
        (_) async => MultiformatBidResult(resultCode: 'prebidDemandNoBids'),
      );
      await PrebidInterstitialAdUnit(
        configId: 'i',
        minSizePercentage: const Size(50, 60),
        pbAdSlot: '/i',
      ).fetchDemand();
      final config =
          verify(api.fetchDemand(any, captureAny)).captured.single
              as MultiformatAdRequestConfig;
      expect(config.bannerSizes, isNull);
      expect(config.isInterstitial, isTrue);
      expect(config.interstitialMinWidthPercentage, 50);
      expect(config.interstitialMinHeightPercentage, 60);
      expect(config.pbAdSlot, '/i');
      expect(
        () => PrebidMultiformatAd(configId: 'x').fetchDemand(),
        throwsArgumentError,
      );
    });

    test('findPrebidCreativeSize converts the size', () async {
      when(api.findPrebidCreativeSize(any)).thenAnswer((_) async => [300, 250]);
      final ad = PrebidMultiformatAd(
        configId: 'm',
        bannerSizes: const [Size(300, 250)],
      );
      expect(await ad.findPrebidCreativeSize(), const Size(300, 250));
      when(api.findPrebidCreativeSize(any)).thenAnswer((_) async => null);
      expect(await ad.findPrebidCreativeSize(), isNull);
    });
  });

  group('native', () {
    late MockNativeAdHostApi api;
    late FakePlatformViews platform;

    setUp(() {
      api = MockNativeAdHostApi();
      PrebidNativeAd.api = api;
      platform = FakePlatformViews(channelPrefix: 'prebid_mobile_sdk/native_ad')
        ..install();
    });

    tearDown(() => platform.uninstall());

    test('sends the request extras and image MIME types', () async {
      await PrebidNativeAd(
        configId: 'n',
        assets: const [
          NativeAsset.image(mimes: ['image/png']),
        ],
        sequence: 2,
        privacy: true,
        ext: const {'k': 1},
        globalOrtbConfig: '{}',
      ).loadAd();
      final config =
          verify(api.loadAd(any, captureAny)).captured.single
              as NativeAdRequestConfig;
      expect(config.assets!.single!.imageMimes, ['image/png']);
      expect(config.sequence, 2);
      expect(config.privacy, isTrue);
      expect(config.ext, '{"k":1}');
      expect(config.globalOrtbConfig, '{}');
    });

    test('loads from a cache id and performs clicks', () async {
      when(api.performClick(any)).thenAnswer((_) async => true);
      final ad = PrebidNativeAd(configId: 'n');
      await ad.loadFromCacheId('cache-1');
      final adId = verify(
        api.loadFromCacheId(captureAny, 'cache-1'),
      ).captured.single;
      expect(await ad.performClick(), isTrue);
      verify(api.performClick(adId as int)).called(1);
    });

    testWidgets('custom layout: tracking view under the child, tap clicks', (
      tester,
    ) async {
      when(api.performClick(any)).thenAnswer((_) async => true);
      final ad = PrebidNativeAd(configId: 'n');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: PrebidNativeAdView.custom(
              ad: ad,
              child: const SizedBox(width: 200, height: 100),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(platform.views.single.params?['layout'], 'custom');
      expect(
        tester.getSize(find.byType(PrebidNativeAdView)),
        const Size(200, 100),
      );
      await tester.tap(find.byType(SizedBox).last);
      verify(api.performClick(any)).called(1);
    }, variant: _ios);
  });

  test('PrebidWinningBid reads the banner payload', () {
    final bid = PrebidWinningBid.fromPayload({
      'price': 0.5,
      'bidder': 'appnexus',
      'width': 320,
      'height': 50,
      'targetingKeywords': {'hb_pb': '0.50'},
    });
    expect(bid?.price, 0.5);
    expect(bid?.bidder, 'appnexus');
    expect(bid?.size, const Size(320, 50));
    expect(bid?.targetingKeywords, {'hb_pb': '0.50'});
    expect(PrebidWinningBid.fromPayload(null), isNull);
  });
}
