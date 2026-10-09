import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

import 'mock_host_api.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrebidInterstitialAd', () {
    late MockInterstitialAdHostApi mockApi;

    setUp(() {
      mockApi = MockInterstitialAdHostApi();
      PrebidInterstitialAd.api = mockApi;
    });

    test('loadAd, show, and destroy calls pigeon api', () async {
      final ad = PrebidInterstitialAd(
        configId: 'config-1',
        adFormats: {AdFormat.banner, AdFormat.video},
        impOrtbConfig: '{"ext":{"gpid":"/1/i"}}',
      );

      await ad.loadAd();
      verify(
        mockApi.loadAd(
          any,
          'config-1',
          any,
          any,
          '{"ext":{"gpid":"/1/i"}}',
          null,
        ),
      ).called(1);

      await ad.show();
      verify(mockApi.show(any)).called(1);

      await ad.destroy();
      verify(mockApi.destroy(any)).called(1);
    });

    test('platform errors reach the caller', () async {
      when(
        mockApi.show(any),
      ).thenThrow(PlatformException(code: 'error', message: 'boom'));
      final ad = PrebidInterstitialAd(configId: 'config-1');

      await expectLater(ad.show(), throwsA(isA<PlatformException>()));
    });
  });

  group('PrebidFullscreenControls', () {
    test('interstitial forwards controls and min size', () async {
      final mockApi = MockInterstitialAdHostApi();
      PrebidInterstitialAd.api = mockApi;
      final ad = PrebidInterstitialAd(
        configId: 'config-c',
        controls: const PrebidFullscreenControls(
          closeButtonArea: 0.2,
          closeButtonPosition: PrebidButtonPosition.topLeft,
          skipButtonPosition: PrebidButtonPosition.topRight,
          skipDelay: 5,
          isMuted: true,
          isSoundButtonVisible: true,
          isAutoCloseOnCompletionEnabled: false,
          minSizePercentage: Size(50, 70),
        ),
      );
      await ad.loadAd();
      final c =
          verify(
                mockApi.loadAd(any, 'config-c', any, any, any, captureAny),
              ).captured.single
              as FullscreenControlsConfig;
      expect(c.closeButtonArea, 0.2);
      expect(c.closeButtonPosition, 'topLeft');
      expect(c.skipButtonPosition, 'topRight');
      expect(c.skipDelay, 5);
      expect(c.isMuted, isTrue);
      expect(c.isSoundButtonVisible, isTrue);
      expect(c.isAutoCloseOnCompletionEnabled, isFalse);
      expect(c.minWidthPercentage, 50);
      expect(c.minHeightPercentage, 70);
    });

    test('toMap omits unset fields', () {
      expect(const PrebidFullscreenControls(skipDelay: 3).toMap(), {
        'skipDelay': 3,
      });
    });
  });

  group('PrebidRewardedAd', () {
    late MockRewardedAdHostApi mockApi;

    setUp(() {
      mockApi = MockRewardedAdHostApi();
      PrebidRewardedAd.api = mockApi;
    });

    test('loadAd, show, and destroy calls pigeon api', () async {
      final ad = PrebidRewardedAd(configId: 'config-2', impOrtbConfig: '{}');

      await ad.loadAd();
      verify(mockApi.loadAd(any, 'config-2', '{}', null)).called(1);

      await ad.show();
      verify(mockApi.show(any)).called(1);

      await ad.destroy();
      verify(mockApi.destroy(any)).called(1);
    });
  });

  group('PrebidNativeAd', () {
    late MockNativeAdHostApi mockApi;

    setUp(() {
      mockApi = MockNativeAdHostApi();
      PrebidNativeAd.api = mockApi;
    });

    test('loadAd and destroy call api', () async {
      final ad = PrebidNativeAd(
        configId: 'config-3',
        assets: [const NativeAsset.title(length: 90)],
      );

      await ad.loadAd();
      verify(mockApi.loadAd(any, any)).called(1);

      await ad.destroy();
      verify(mockApi.destroy(any)).called(1);
    });
  });

  group('PrebidMultiformatAd', () {
    late MockMultiformatAdHostApi mockApi;

    setUp(() {
      mockApi = MockMultiformatAdHostApi();
      PrebidMultiformatAd.api = mockApi;
    });

    test('fetchDemand and destroy calls api', () async {
      final ad = PrebidMultiformatAd(
        configId: 'config-4',
        bannerSizes: [const Size(300, 250)],
        videoParameters: const VideoParameters(mimes: ['video/mp4']),
      );

      when(mockApi.fetchDemand(any, any)).thenAnswer(
        (_) async => MultiformatBidResult(
          resultCode: 'prebidDemandFetchSuccess',
          winningFormat: 'banner',
        ),
      );

      final result = await ad.fetchDemand();
      expect(result.isSuccess, isTrue);
      expect(result.winningFormat, 'banner');

      verify(mockApi.fetchDemand(any, any)).called(1);

      await ad.destroy();
      verify(mockApi.destroy(any)).called(1);
    });

    test('forwards gpid and maps exp / topBidFiltered', () async {
      final ad = PrebidMultiformatAd(configId: 'config-5', gpid: '/1111/home');
      when(mockApi.fetchDemand(any, any)).thenAnswer(
        (_) async => MultiformatBidResult(
          resultCode: 'prebidDemandFetchSuccess',
          exp: 300,
          topBidFiltered: true,
        ),
      );

      final result = await ad.fetchDemand();
      final config =
          verify(mockApi.fetchDemand(any, captureAny)).captured.single
              as MultiformatAdRequestConfig;
      expect(config.gpid, '/1111/home');
      expect(result.exp, 300);
      expect(result.topBidFiltered, isTrue);
    });
  });

  group('PrebidBannerAdUnit (Original API)', () {
    late MockMultiformatAdHostApi mockApi;

    setUp(() {
      mockApi = MockMultiformatAdHostApi();
      PrebidMultiformatAd.api = mockApi;
    });

    test('fetchDemand returns keywords and destroy calls api', () async {
      final adUnit = PrebidBannerAdUnit(
        configId: 'config-banner',
        sizes: const [Size(300, 250)],
      );

      when(mockApi.fetchDemand(any, any)).thenAnswer(
        (_) async => MultiformatBidResult(
          resultCode: 'prebidDemandFetchSuccess',
          winningFormat: 'banner',
          targetingKeywords: {'hb_pb': '1.50'},
        ),
      );

      final response = await adUnit.fetchDemand();
      expect(response.isSuccess, isTrue);
      expect(response.targetingKeywords?['hb_pb'], '1.50');

      verify(mockApi.fetchDemand(any, any)).called(1);

      await adUnit.destroy();
      verify(mockApi.destroy(any)).called(1);
    });
  });

  group('PrebidInterstitialAdUnit (Original API)', () {
    late MockMultiformatAdHostApi mockApi;

    setUp(() {
      mockApi = MockMultiformatAdHostApi();
      PrebidMultiformatAd.api = mockApi;
    });

    test('fetchDemand runs and destroy calls api', () async {
      final adUnit = PrebidInterstitialAdUnit(
        configId: 'config-interstitial',
        sizes: const [Size(320, 480)],
      );

      when(mockApi.fetchDemand(any, any)).thenAnswer(
        (_) async => MultiformatBidResult(resultCode: 'prebidDemandNoBids'),
      );

      final response = await adUnit.fetchDemand();
      expect(response.isSuccess, isFalse);

      verify(mockApi.fetchDemand(any, any)).called(1);

      await adUnit.destroy();
      verify(mockApi.destroy(any)).called(1);
    });
  });
}
