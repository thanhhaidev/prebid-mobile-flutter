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
        api.loadAd(any, 'r', captureAny, captureAny, any, captureAny, any),
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
