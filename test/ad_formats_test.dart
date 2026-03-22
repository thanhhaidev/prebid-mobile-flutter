import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
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
      );

      await ad.loadAd();
      verify(mockApi.loadAd(any, 'config-1', any, any)).called(1);

      await ad.show();
      verify(mockApi.show(any)).called(1);

      await ad.destroy();
      verify(mockApi.destroy(any)).called(1);
    });
  });

  group('PrebidRewardedAd', () {
    late MockRewardedAdHostApi mockApi;

    setUp(() {
      mockApi = MockRewardedAdHostApi();
      PrebidRewardedAd.api = mockApi;
    });

    test('loadAd, show, and destroy calls pigeon api', () async {
      final ad = PrebidRewardedAd(configId: 'config-2');

      await ad.loadAd();
      verify(mockApi.loadAd(any, 'config-2')).called(1);

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

    test('loadAd, trackImpression, trackClick, destroy calls api', () async {
      final ad = PrebidNativeAd(
        configId: 'config-3',
        assets: [const NativeAsset.title(length: 90)],
      );

      await ad.loadAd();
      verify(mockApi.loadAd(any, any)).called(1);

      await ad.trackImpression();
      verify(mockApi.trackImpression(any)).called(1);

      await ad.trackClick();
      verify(mockApi.trackClick(any)).called(1);

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
  });
}
