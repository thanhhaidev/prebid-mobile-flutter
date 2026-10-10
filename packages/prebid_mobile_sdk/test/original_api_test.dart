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
      (_) async => MultiformatBidResult(
        resultCode: 'prebidDemandFetchSuccess',
        targetingKeywords: {'hb_pb': '1.00'},
        exp: 300,
        topBidFiltered: true,
        events: {'ext.prebid.events.win': 'https://win'},
        nativeAdCacheId: 'cache-1',
      ),
    );
  });

  MultiformatAdRequestConfig lastRequest() =>
      verify(api.fetchDemand(any, captureAny)).captured.last
          as MultiformatAdRequestConfig;

  Future<int> lastAdId() async =>
      verify(api.fetchDemand(captureAny, any)).captured.last as int;

  group('PrebidBannerAdUnit', () {
    test('requests a banner and returns the keywords', () async {
      final response = await PrebidBannerAdUnit(
        configId: 'b',
        sizes: const [Size(300, 250)],
        adPosition: PrebidAdPosition.header,
        gpid: '/1/home',
        pbAdSlot: '/slot',
        impOrtbConfig: '{"imp":1}',
        globalOrtbConfig: '{"app":{}}',
      ).fetchDemand();

      final c = lastRequest();
      expect(c.configId, 'b');
      expect(c.bannerSizes, [300, 250]);
      expect((c.isInterstitial, c.isRewarded), (false, false));
      expect((c.videoConfig, c.nativeConfig), (null, null));
      expect((c.adPosition, c.gpid, c.pbAdSlot), (4, '/1/home', '/slot'));
      expect(
        (c.impOrtbConfig, c.globalOrtbConfig),
        ('{"imp":1}', '{"app":{}}'),
      );

      expect(response.isSuccess, isTrue);
      expect(response.targetingKeywords, {'hb_pb': '1.00'});
      expect((response.exp, response.topBidFiltered), (300, true));
      expect(response.events, {'ext.prebid.events.win': 'https://win'});
    });

    test('impression tracking and auto-refresh act on this unit', () async {
      final refreshed = <PrebidBidResponse>[];
      final unit = PrebidBannerAdUnit(
        configId: 'b',
        sizes: const [Size(320, 50)],
        onDemandRefreshed: refreshed.add,
      );
      await unit.fetchDemand();
      final id = await lastAdId();
      when(
        api.activateBannerImpressionTracker(id),
      ).thenAnswer((_) async => true);
      expect(await unit.activateImpressionTracker(), isTrue);

      await unit.setAutoRefreshInterval(30);
      await unit.stopAutoRefresh();
      await unit.resumeAutoRefresh();
      verify(api.setAutoRefreshInterval(id, 30)).called(1);
      verify(api.stopAutoRefresh(id)).called(1);
      verify(api.resumeAutoRefresh(id)).called(1);

      await sendDemandRefreshed(
        id,
        MultiformatBidResult(
          resultCode: 'prebidDemandFetchSuccess',
          targetingKeywords: {'hb_pb': '0.20'},
        ),
      );
      expect(refreshed.single.targetingKeywords, {'hb_pb': '0.20'});
    });
  });

  group('PrebidInterstitialAdUnit', () {
    test('requests an interstitial with its formats and options', () async {
      await PrebidInterstitialAdUnit(
        configId: 'i',
        sizes: const [Size(320, 480)],
        videoParameters: const VideoParameters(mimes: ['video/mp4']),
        trackImpression: true,
        gpid: '/1/i',
        pbAdSlot: '/i',
      ).fetchDemand();
      final c = lastRequest();
      expect(c.bannerSizes, [320, 480]);
      expect(c.videoConfig?.mimes, ['video/mp4']);
      expect((c.isInterstitial, c.isRewarded), (true, false));
      expect(c.trackInterstitialImpression, isTrue);
      expect((c.gpid, c.pbAdSlot), ('/1/i', '/i'));
    });

    test('a minimum size alone asks for the display format', () async {
      await PrebidInterstitialAdUnit(
        configId: 'i',
        minSizePercentage: const Size(50, 60),
      ).fetchDemand();
      final c = lastRequest();
      expect(c.bannerSizes, isNull);
      expect(
        (c.interstitialMinWidthPercentage, c.interstitialMinHeightPercentage),
        (50, 60),
      );
    });

    test('without sizes, video or a minimum size it is rejected', () async {
      await expectLater(
        PrebidInterstitialAdUnit(configId: 'i').fetchDemand(),
        throwsArgumentError,
      );
      verifyNever(api.fetchDemand(any, any));
    });
  });

  group('PrebidRewardedAdUnit', () {
    test('requests a rewarded video interstitial', () async {
      final response = await PrebidRewardedAdUnit(
        configId: 'r',
        videoParameters: const VideoParameters(
          mimes: ['video/mp4'],
          maxDuration: 30,
        ),
        trackImpression: true,
        gpid: '/1/rewarded',
        pbAdSlot: '/slot',
        impOrtbConfig: '{"ext":{}}',
        globalOrtbConfig: '{"app":{}}',
      ).fetchDemand();

      final c = lastRequest();
      expect(c.configId, 'r');
      expect((c.isInterstitial, c.isRewarded), (true, true));
      expect((c.bannerSizes, c.nativeConfig), (null, null));
      expect(c.videoConfig?.mimes, ['video/mp4']);
      expect(c.videoConfig?.maxDuration, 30);
      expect(c.trackInterstitialImpression, isTrue);
      expect((c.gpid, c.pbAdSlot), ('/1/rewarded', '/slot'));
      expect(
        (c.impOrtbConfig, c.globalOrtbConfig),
        ('{"ext":{}}', '{"app":{}}'),
      );
      expect(response.targetingKeywords, {'hb_pb': '1.00'});
    });
  });

  group('PrebidNativeAdUnit', () {
    test('requests native demand and returns the cache id', () async {
      final response = await PrebidNativeAdUnit(
        configId: 'n',
        pbAdSlot: '/slot',
        nativeParameters: const NativeParameters(
          assets: [NativeAsset.title()],
          context: NativeContextType.contentCentric,
          contextSubType: NativeContextSubType.article,
          placementType: NativePlacementType.inFeed,
          placementCount: 2,
          sequence: 1,
          assetUrlSupport: true,
          dUrlSupport: false,
          privacy: true,
          ext: {'k': 1},
        ),
      ).fetchDemand();

      final c = lastRequest();
      expect((c.bannerSizes, c.videoConfig), (null, null));
      expect(c.pbAdSlot, '/slot');
      final native = c.nativeConfig!;
      expect(native.configId, 'n');
      expect(
        (native.context, native.contextSubType, native.placementType),
        (1, 11, 1),
      );
      expect((native.placementCount, native.sequence), (2, 1));
      expect(
        (native.assetUrlSupport, native.dUrlSupport, native.privacy),
        (true, false, true),
      );
      expect(native.ext, '{"k":1}');
      expect(response.nativeAdCacheId, 'cache-1');
    });

    test('requests the default assets when none are set', () async {
      await PrebidNativeAdUnit(configId: 'n').fetchDemand();
      expect(lastRequest().nativeConfig!.assets, hasLength(6));
    });
  });

  test(
    'every unit takes refreshes again after destroy and a new fetch',
    () async {
      final banner = <PrebidBidResponse>[];
      final interstitial = <PrebidBidResponse>[];
      final native = <PrebidNativeBidResponse>[];
      final bannerUnit = PrebidBannerAdUnit(
        configId: 'b',
        sizes: const [Size(300, 250)],
        onDemandRefreshed: banner.add,
      );
      final interstitialUnit = PrebidInterstitialAdUnit(
        configId: 'i',
        sizes: const [Size(320, 480)],
        onDemandRefreshed: interstitial.add,
      );
      final nativeUnit = PrebidNativeAdUnit(
        configId: 'n',
        onDemandRefreshed: native.add,
      );
      final units =
          <(Future<Object?> Function(), Future<void> Function(), List<Object>)>[
            (bannerUnit.fetchDemand, bannerUnit.destroy, banner),
            (
              interstitialUnit.fetchDemand,
              interstitialUnit.destroy,
              interstitial,
            ),
            (nativeUnit.fetchDemand, nativeUnit.destroy, native),
          ];
      final refreshed = MultiformatBidResult(
        resultCode: 'prebidDemandFetchSuccess',
        nativeAdCacheId: 'cache-2',
      );

      for (final (fetchDemand, destroy, received) in units) {
        await fetchDemand();
        final id = await lastAdId();
        await destroy();
        verify(api.destroy(id)).called(1);
        await sendDemandRefreshed(id, refreshed);
        expect(received, isEmpty);

        await fetchDemand();
        await sendDemandRefreshed(id, refreshed);
        expect(received, hasLength(1));
      }
      expect(native.single.nativeAdCacheId, 'cache-2');
    },
  );

  test('isSuccess follows the result code', () {
    expect(
      const PrebidBidResponse(resultCode: 'prebidDemandFetchSuccess').isSuccess,
      isTrue,
    );
    expect(
      const PrebidBidResponse(resultCode: 'prebidDemandNoBids').isSuccess,
      isFalse,
    );
  });
}
