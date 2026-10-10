import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

import 'mock_host_api.mocks.dart';
import 'platform_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMultiformatAdHostApi api;

  setUp(() {
    api = MockMultiformatAdHostApi();
    PrebidMultiformatAd.api = api;
    when(api.fetchDemand(any, any)).thenAnswer(
      (_) async => MultiformatBidResult(resultCode: 'prebidDemandNoBids'),
    );
  });

  MultiformatAdRequestConfig lastRequest() =>
      verify(api.fetchDemand(any, captureAny)).captured.last
          as MultiformatAdRequestConfig;

  Future<int> lastAdId() async =>
      verify(api.fetchDemand(captureAny, any)).captured.last as int;

  group('fetchDemand', () {
    test('sends the whole request', () async {
      await PrebidMultiformatAd(
        configId: 'm',
        bannerSizes: const [Size(320, 50), Size(300, 250)],
        videoParameters: const VideoParameters(mimes: ['video/mp4']),
        nativeParameters: const NativeParameters(assets: [NativeAsset.title()]),
        isInterstitial: true,
        isRewarded: true,
        gpid: '/1/home',
        adPosition: PrebidAdPosition.header,
        trackInterstitialImpression: true,
        bannerApi: const [VideoApi.mraid2, VideoApi.omid1],
        interstitialMinSizePercentage: const Size(49.6, 70.2),
        supportSKOverlay: true,
        pbAdSlot: '/slot',
        impOrtbConfig: '{"imp":1}',
        globalOrtbConfig: '{"app":{}}',
      ).fetchDemand();

      final c = lastRequest();
      expect(c.configId, 'm');
      expect(c.bannerSizes, [320, 50, 300, 250]);
      expect(c.videoConfig?.mimes, ['video/mp4']);
      expect(c.nativeConfig?.assets?.single?.assetType, 'title');
      expect((c.isInterstitial, c.isRewarded), (true, true));
      expect((c.gpid, c.adPosition), ('/1/home', 4));
      expect(c.trackInterstitialImpression, isTrue);
      expect(c.bannerApi, [5, 7]);
      expect(
        (c.interstitialMinWidthPercentage, c.interstitialMinHeightPercentage),
        (50, 70),
      );
      expect(c.supportSKOverlay, isTrue);
      expect(
        (c.pbAdSlot, c.impOrtbConfig, c.globalOrtbConfig),
        ('/slot', '{"imp":1}', '{"app":{}}'),
      );
    });

    test('asks for native demand only with native parameters', () async {
      await PrebidMultiformatAd(
        configId: 'm',
        bannerSizes: const [Size(300, 250)],
      ).fetchDemand();
      expect(lastRequest().nativeConfig, isNull);
    });

    test('an interstitial with a minimum size needs no banner size', () async {
      await PrebidMultiformatAd(
        configId: 'm',
        isInterstitial: true,
        interstitialMinSizePercentage: const Size(50, 60),
      ).fetchDemand();
      expect(lastRequest().bannerSizes, isNull);
    });

    test('rejects a request without any format', () async {
      await expectLater(
        PrebidMultiformatAd(configId: 'x').fetchDemand(),
        throwsArgumentError,
      );
      verifyNever(api.fetchDemand(any, any));
    });

    test('returns the platform result', () async {
      when(api.fetchDemand(any, any)).thenAnswer(
        (_) async => MultiformatBidResult(
          resultCode: 'prebidDemandFetchSuccess',
          winningFormat: 'native',
          targetingKeywords: {'hb_pb': '1.00', 'drop': null, null: 'x'},
          nativeAdCacheId: 'cache-1',
          exp: 300,
          topBidFiltered: true,
          events: {'ext.prebid.events.win': 'https://win', 'x': null},
        ),
      );
      final r = await PrebidMultiformatAd(
        configId: 'm',
        bannerSizes: const [Size(320, 50)],
      ).fetchDemand();
      expect(r.isSuccess, isTrue);
      expect(r.winningFormat, 'native');
      expect(r.targetingKeywords, {'hb_pb': '1.00'});
      expect(r.nativeAdCacheId, 'cache-1');
      expect((r.exp, r.topBidFiltered), (300, true));
      expect(r.events, {'ext.prebid.events.win': 'https://win'});
      expect(r.expiresAt, r.receivedAt!.add(const Duration(seconds: 300)));
      expect(r.isExpired, isFalse);
    });

    test('an empty result has no keywords, no events, no filtering', () async {
      final r = await PrebidMultiformatAd(
        configId: 'm',
        bannerSizes: const [Size(320, 50)],
      ).fetchDemand();
      expect(r.isSuccess, isFalse);
      expect(r.targetingKeywords, isNull);
      expect(r.events, isEmpty);
      expect(r.topBidFiltered, isFalse);
    });
  });

  group('auto-refresh', () {
    test('the controls reach the platform for this ad', () async {
      final ad = PrebidMultiformatAd(
        configId: 'm',
        bannerSizes: const [Size(320, 50)],
      );
      await ad.fetchDemand();
      final id = await lastAdId();
      await ad.setAutoRefreshInterval(30);
      await ad.stopAutoRefresh();
      await ad.resumeAutoRefresh();
      verify(api.setAutoRefreshInterval(id, 30)).called(1);
      verify(api.stopAutoRefresh(id)).called(1);
      verify(api.resumeAutoRefresh(id)).called(1);
    });

    test('refreshed results reach onDemandRefreshed', () async {
      final results = <PrebidMultiformatBidResponse>[];
      final ad = PrebidMultiformatAd(
        configId: 'm',
        bannerSizes: const [Size(320, 50)],
        onDemandRefreshed: results.add,
      );
      await ad.fetchDemand();
      await sendDemandRefreshed(
        await lastAdId(),
        MultiformatBidResult(
          resultCode: 'prebidDemandFetchSuccess',
          winningFormat: 'banner',
          targetingKeywords: {'hb_pb': '1.00'},
        ),
      );
      expect(results.single.isSuccess, isTrue);
      expect(results.single.winningFormat, 'banner');
      expect(results.single.targetingKeywords, {'hb_pb': '1.00'});
    });

    test(
      'refreshes stop after destroy and come back with the next fetch',
      () async {
        final results = <PrebidMultiformatBidResponse>[];
        final ad = PrebidMultiformatAd(
          configId: 'm',
          bannerSizes: const [Size(320, 50)],
          onDemandRefreshed: results.add,
        );
        await ad.fetchDemand();
        final id = await lastAdId();
        final refreshed = MultiformatBidResult(
          resultCode: 'prebidDemandNoBids',
        );

        await ad.destroy();
        verify(api.destroy(id)).called(1);
        await sendDemandRefreshed(id, refreshed);
        expect(results, isEmpty);

        await ad.fetchDemand();
        await sendDemandRefreshed(id, refreshed);
        expect(results, hasLength(1));
      },
    );
  });

  group('the ad server banner', () {
    late PrebidMultiformatAd ad;
    late int id;

    setUp(() async {
      ad = PrebidMultiformatAd(
        configId: 'm',
        bannerSizes: const [Size(300, 250)],
      );
      await ad.fetchDemand();
      id = await lastAdId();
    });

    test('impression tracking returns the platform answer', () async {
      when(
        api.activateBannerImpressionTracker(id),
      ).thenAnswer((_) async => true);
      expect(await ad.activateBannerImpressionTracker(), isTrue);
    });

    test('the Prebid creative size is a Size, null when not found', () async {
      when(api.findPrebidCreativeSize(id)).thenAnswer((_) async => [300, 250]);
      expect(await ad.findPrebidCreativeSize(), const Size(300, 250));
      when(api.findPrebidCreativeSize(id)).thenAnswer((_) async => null);
      expect(await ad.findPrebidCreativeSize(), isNull);
    });

    test('the SKAdNetwork calls reach the platform for this ad', () async {
      when(api.activateBannerSKAdNetwork(id)).thenAnswer((_) async => false);
      expect(await ad.activateBannerSKAdNetwork(), isFalse);
      await ad.activateInterstitialSKAdNetwork();
      await ad.activateSKOverlay();
      await ad.dismissSKOverlay();
      verify(api.activateInterstitialSKAdNetwork(id)).called(1);
      verify(api.activateSKOverlay(id)).called(1);
      verify(api.dismissSKOverlay(id)).called(1);
    });
  });
}
