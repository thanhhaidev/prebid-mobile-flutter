import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';
import 'package:prebid_mobile_sdk/src/internal/ad_event_router.dart';
import 'package:prebid_mobile_sdk/src/internal/multiformat_event_router.dart';
import 'package:prebid_mobile_sdk/src/internal/pigeon_conversions.dart';

import 'mock_host_api.mocks.dart';

const _video = VideoParameters(
  mimes: ['video/mp4'],
  protocols: [VideoProtocol.vast4_0],
  placement: VideoPlacement.inArticle,
  plcmt: VideoPlcmt.accompanyingContent,
  startDelay: VideoStartDelay.genericMidRoll,
  linearity: VideoLinearity.linear,
  skippable: true,
  battr: [VideoCreativeAttribute.annoying, VideoCreativeAttribute.surveys],
  minBitrate: 300,
  maxBitrate: 1500,
  maxDuration: 30,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoParameters', () {
    test('toConfig carries the OpenRTB 2.6 fields', () {
      final c = _video.toConfig();
      expect(c.mimes, ['video/mp4']);
      expect(c.protocols, [7]);
      expect(c.placement, 3);
      expect(c.plcmt, 2);
      expect(c.startDelay, -1);
      expect(c.linearity, 1);
      expect(c.skippable, isTrue);
      expect(c.battr, [10, 11]);
      expect(c.minBitrate, 300);
      expect(c.maxBitrate, 1500);
      expect(c.maxDuration, 30);
    });

    test('toMap omits unset fields', () {
      expect(const VideoParameters(mimes: ['video/mp4']).toMap(), {
        'mimes': ['video/mp4'],
      });
      expect(_video.toMap(), containsPair('plcmt', 2));
      expect(_video.toMap(), containsPair('battr', [10, 11]));
    });
  });

  test('in-stream sends video parameters and maps exp', () async {
    final mockApi = MockInstreamVideoAdHostApi();
    PrebidInstreamVideoAd.api = mockApi;
    when(mockApi.fetchDemand(any, any)).thenAnswer(
      (_) async => MultiformatBidResult(
        resultCode: 'prebidDemandFetchSuccess',
        targetingKeywords: {'hb_pb': '0.10'},
        exp: 300,
      ),
    );

    final ad = PrebidInstreamVideoAd(
      configId: 'video',
      size: const Size(640, 480),
      videoParameters: _video,
    );
    final result = await ad.fetchDemand();

    final config =
        verify(mockApi.fetchDemand(any, captureAny)).captured.single
            as InstreamVideoAdRequestConfig;
    expect(config.videoConfig?.plcmt, 2);
    expect(config.videoConfig?.mimes, ['video/mp4']);
    expect(result.exp, 300);
    expect(result.targetingKeywords, {'hb_pb': '0.10'});
  });

  test('native response exposes privacy URL and every asset', () async {
    final mockApi = MockNativeAdHostApi();
    PrebidNativeAd.api = mockApi;
    PrebidNativeAdResponse? response;
    final ad = PrebidNativeAd(
      configId: 'native',
      listener: PrebidNativeAdListener(onAdLoaded: (r) => response = r),
    );
    await ad.loadAd();
    final adId = verify(mockApi.loadAd(captureAny, any)).captured.single as int;

    await AdEventRouter.instance.onAdEvent(
      AdEvent(
        adId: adId,
        eventName: 'onAdLoaded',
        nativeAd: NativeAdData(
          title: 'Title',
          privacyUrl: 'https://privacy.example',
          titles: ['Title'],
          images: [NativeAdImageData(type: 3, url: 'https://img')],
          dataAssets: [
            NativeAdDataAssetData(type: 3, value: '4.5'),
            NativeAdDataAssetData(type: 6, value: r'$1.99'),
          ],
        ),
      ),
    );

    expect(response?.privacyUrl, 'https://privacy.example');
    expect(response?.titles, ['Title']);
    expect(response?.images.single.url, 'https://img');
    expect(response?.dataOf(NativeDataType.rating), ['4.5']);
    expect(response?.dataOf(NativeDataType.price), [r'$1.99']);
    await ad.destroy();
  });

  test('fullscreen controls carry supportSKOverlay', () {
    const controls = PrebidFullscreenControls(supportSKOverlay: true);
    expect(controls.toConfig().supportSKOverlay, isTrue);
    expect(controls.toMap(), {'supportSKOverlay': true});
  });

  test('initializeSdk forwards the non-tracking URL', () async {
    final mockApi = MockPrebidMobileHostApi();
    PrebidMobile.api = mockApi;
    when(
      mockApi.initializeSdk(any, any, any),
    ).thenAnswer((_) async => InitializationResult(status: 'succeeded'));

    await PrebidMobile.initializeSdk(
      prebidServerUrl: 'https://pbs',
      accountId: 'acc',
      nonTrackingUrl: 'https://pbs-no-track',
    );
    verify(
      mockApi.initializeSdk('https://pbs', 'acc', 'https://pbs-no-track'),
    ).called(1);
  });

  test('targeting sets source app and iTunes ID', () async {
    final mockApi = MockTargetingHostApi();
    PrebidTargeting.api = mockApi;
    await PrebidTargeting.setSourceApp('123456789');
    await PrebidTargeting.setItunesId('123456789');
    verify(mockApi.setSourceApp('123456789')).called(1);
    verify(mockApi.setItunesId('123456789')).called(1);
  });

  test('status check and purpose consent', () async {
    final mobile = MockPrebidMobileHostApi();
    PrebidMobile.api = mobile;
    await PrebidMobile.setDisableStatusCheck(true);
    verify(mobile.setDisableStatusCheck(true)).called(1);

    final targeting = MockTargetingHostApi();
    PrebidTargeting.api = targeting;
    when(targeting.getPurposeConsent(0)).thenAnswer((_) async => true);
    expect(await PrebidTargeting.getPurposeConsent(0), isTrue);
  });

  group('Original API', () {
    late MockMultiformatAdHostApi mockApi;

    setUp(() {
      mockApi = MockMultiformatAdHostApi();
      PrebidMultiformatAd.api = mockApi;
      when(mockApi.fetchDemand(any, any)).thenAnswer(
        (_) async => MultiformatBidResult(
          resultCode: 'prebidDemandFetchSuccess',
          targetingKeywords: {'hb_pb': '0.10'},
        ),
      );
      when(
        mockApi.activateBannerImpressionTracker(any),
      ).thenAnswer((_) async => true);
    });

    test('banner unit sends position, refreshes and tracks', () async {
      final refreshed = <PrebidBidResponse>[];
      final unit = PrebidBannerAdUnit(
        configId: 'banner',
        sizes: const [Size(320, 50)],
        adPosition: PrebidAdPosition.header,
        onDemandRefreshed: refreshed.add,
      );
      await unit.fetchDemand();
      final captured = verify(
        mockApi.fetchDemand(captureAny, captureAny),
      ).captured;
      final adId = captured[0] as int;
      expect((captured[1] as MultiformatAdRequestConfig).adPosition, 4);

      await unit.setAutoRefreshInterval(30);
      verify(mockApi.setAutoRefreshInterval(adId, 30)).called(1);
      await unit.stopAutoRefresh();
      verify(mockApi.stopAutoRefresh(adId)).called(1);
      await unit.resumeAutoRefresh();
      verify(mockApi.resumeAutoRefresh(adId)).called(1);
      expect(await unit.activateImpressionTracker(), isTrue);

      await MultiformatEventRouter.instance.onDemandRefreshed(
        adId,
        MultiformatBidResult(
          resultCode: 'prebidDemandFetchSuccess',
          targetingKeywords: {'hb_pb': '0.20'},
        ),
      );
      expect(refreshed.single.targetingKeywords, {'hb_pb': '0.20'});

      await unit.destroy();
      await MultiformatEventRouter.instance.onDemandRefreshed(
        adId,
        MultiformatBidResult(resultCode: 'prebidDemandNoBids'),
      );
      expect(refreshed, hasLength(1));
    });

    test('a request without any format is rejected', () async {
      final unit = PrebidInterstitialAdUnit(configId: 'inter');
      await expectLater(unit.fetchDemand(), throwsArgumentError);
      verifyNever(mockApi.fetchDemand(any, any));
    });

    test('interstitial unit asks for impression tracking', () async {
      final unit = PrebidInterstitialAdUnit(
        configId: 'inter',
        sizes: const [Size(320, 480)],
        trackImpression: true,
      );
      await unit.fetchDemand();
      final config =
          verify(mockApi.fetchDemand(any, captureAny)).captured.single
              as MultiformatAdRequestConfig;
      expect(config.trackInterstitialImpression, isTrue);
      expect(config.isInterstitial, isTrue);
    });

    test('native unit sends context, subtype and placement', () async {
      final unit = PrebidNativeAdUnit(
        configId: 'native',
        nativeParameters: const NativeParameters(
          assets: [NativeAsset.title()],
          context: NativeContextType.contentCentric,
          contextSubType: NativeContextSubType.article,
          placementType: NativePlacementType.inFeed,
        ),
      );
      await unit.fetchDemand();
      final native =
          (verify(mockApi.fetchDemand(any, captureAny)).captured.single
                  as MultiformatAdRequestConfig)
              .nativeConfig!;
      expect(native.context, 1);
      expect(native.contextSubType, 11);
      expect(native.placementType, 1);
    });
  });

  test('native ad sends its context subtype', () async {
    final mockApi = MockNativeAdHostApi();
    PrebidNativeAd.api = mockApi;
    final ad = PrebidNativeAd(
      configId: 'native',
      nativeParameters: const NativeParameters(
        contextSubType: NativeContextSubType.social,
      ),
    );
    await ad.loadAd();
    final config =
        verify(mockApi.loadAd(any, captureAny)).captured.single
            as NativeAdRequestConfig;
    expect(config.contextSubType, 20);
  });
}
