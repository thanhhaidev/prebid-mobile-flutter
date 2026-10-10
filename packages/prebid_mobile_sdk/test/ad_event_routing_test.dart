import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';
import 'package:prebid_mobile_sdk/src/internal/ad_event_router.dart';
import 'package:prebid_mobile_sdk/src/internal/multiformat_event_router.dart';

import 'mock_host_api.mocks.dart';

Future<void> _emit(
  int adId,
  String name, {
  String? error,
  RewardData? reward,
}) => AdEventRouter.instance.onAdEvent(
  AdEvent(adId: adId, eventName: name, error: error, reward: reward),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrebidInterstitialAd events', () {
    late MockInterstitialAdHostApi api;

    setUp(() {
      api = MockInterstitialAdHostApi();
      PrebidInterstitialAd.api = api;
    });

    Future<int> load(PrebidInterstitialAd ad) async {
      await ad.loadAd();
      return verify(
            api.loadAd(captureAny, any, any, any, any, any),
          ).captured.last
          as int;
    }

    PrebidInterstitialAdListener recorder(List<String> events) =>
        PrebidInterstitialAdListener(
          onAdLoaded: () => events.add('loaded'),
          onAdFailed: (e) => events.add('failed:$e'),
          onAdDisplayed: () => events.add('displayed'),
          onAdClosed: () => events.add('closed'),
          onAdClicked: () => events.add('clicked'),
          onAdExpired: () => events.add('expired'),
          onAdImpression: () => events.add('impression'),
        );

    test('every event name reaches the listener', () async {
      final events = <String>[];
      final ad = PrebidInterstitialAd(
        configId: 'i',
        listener: recorder(events),
      );
      final id = await load(ad);

      await _emit(id, 'onAdLoaded');
      await _emit(id, 'onAdFailed', error: 'boom');
      await _emit(id, 'onAdFailed');
      await _emit(id, 'onAdDisplayed');
      await _emit(id, 'onAdClosed');
      await _emit(id, 'onAdClicked');
      await _emit(id, 'onAdExpired');
      await _emit(id, 'onUnknown');

      expect(events, [
        'loaded',
        'failed:boom',
        'failed:Unknown error',
        'displayed',
        'closed',
        'clicked',
        'expired',
      ]);
    });

    test('loadAd sends formats, video parameters and controls', () async {
      final ad = PrebidInterstitialAd(
        configId: 'i',
        adFormats: {PrebidAdFormat.video},
        videoParameters: const VideoParameters(
          mimes: ['video/mp4'],
          maxDuration: 15,
        ),
        controls: const PrebidFullscreenControls(skipDelay: 3),
      );
      await ad.loadAd();
      final captured = verify(
        api.loadAd(any, any, captureAny, captureAny, any, captureAny),
      ).captured;
      expect(captured[0], ['video']);
      expect((captured[1] as VideoParametersConfig).maxDuration, 15);
      expect((captured[2] as FullscreenControlsConfig).skipDelay, 3);
    });

    test('events for other ads are not delivered', () async {
      final a = <String>[];
      final b = <String>[];
      final adA = PrebidInterstitialAd(configId: 'a', listener: recorder(a));
      PrebidInterstitialAd(configId: 'b', listener: recorder(b));
      final idA = await load(adA);

      await _emit(idA, 'onAdLoaded');
      expect(a, ['loaded']);
      expect(b, isEmpty);
    });

    test('an ad without a listener ignores events', () async {
      final ad = PrebidInterstitialAd(configId: 'i');
      final id = await load(ad);
      await _emit(id, 'onAdLoaded');
    });

    test('destroy unregisters the ad', () async {
      final events = <String>[];
      final ad = PrebidInterstitialAd(
        configId: 'i',
        listener: recorder(events),
      );
      final id = await load(ad);

      await ad.destroy();
      verify(api.destroy(id)).called(1);
      await _emit(id, 'onAdLoaded');
      expect(events, isEmpty);
    });

    test('loadAd after destroy delivers events again', () async {
      final events = <String>[];
      final ad = PrebidInterstitialAd(
        configId: 'i',
        listener: recorder(events),
      );
      final id = await load(ad);
      await ad.destroy();

      expect(await load(ad), id);
      await _emit(id, 'onAdLoaded');
      expect(events, ['loaded']);
    });
  });

  group('PrebidRewardedAd events', () {
    late MockRewardedAdHostApi api;

    setUp(() {
      api = MockRewardedAdHostApi();
      PrebidRewardedAd.api = api;
    });

    Future<int> load(PrebidRewardedAd ad) async {
      await ad.loadAd();
      return verify(api.loadAd(captureAny, any, any, any)).captured.last as int;
    }

    test('every event name reaches the listener', () async {
      final events = <String>[];
      final ad = PrebidRewardedAd(
        configId: 'r',
        listener: PrebidRewardedAdListener(
          onAdLoaded: () => events.add('loaded'),
          onAdFailed: (e) => events.add('failed:$e'),
          onAdDisplayed: () => events.add('displayed'),
          onAdClosed: () => events.add('closed'),
          onAdClicked: () => events.add('clicked'),
          onUserEarnedReward: (r) => events.add('reward:${r.count}x${r.type}'),
          onAdExpired: () => events.add('expired'),
        ),
      );
      final id = await load(ad);

      await _emit(id, 'onAdLoaded');
      await _emit(id, 'onAdFailed', error: 'boom');
      await _emit(id, 'onAdFailed');
      await _emit(id, 'onAdDisplayed');
      await _emit(id, 'onAdClosed');
      await _emit(id, 'onAdClicked');
      await _emit(
        id,
        'onUserEarnedReward',
        reward: RewardData(type: 'coins', count: 5),
      );
      await _emit(id, 'onAdExpired');
      await _emit(id, 'onUnknown');

      expect(events, [
        'loaded',
        'failed:boom',
        'failed:Unknown error',
        'displayed',
        'closed',
        'clicked',
        'reward:5xcoins',
        'expired',
      ]);
    });

    test('RewardData maps to PrebidReward', () async {
      final rewards = <PrebidReward>[];
      final ad = PrebidRewardedAd(
        configId: 'r',
        listener: PrebidRewardedAdListener(onUserEarnedReward: rewards.add),
      );
      final id = await load(ad);

      await _emit(
        id,
        'onUserEarnedReward',
        reward: RewardData(
          type: 'gems',
          count: 3,
          ext: {'bonus': true, null: 'x'},
        ),
      );
      await _emit(id, 'onUserEarnedReward', reward: RewardData());
      await _emit(id, 'onUserEarnedReward');

      expect(rewards[0].type, 'gems');
      expect(rewards[0].count, 3);
      expect(rewards[0].ext, {'bonus': true, '': 'x'});
      // Missing values fall back to the platforms' defaults.
      for (final r in rewards.skip(1)) {
        expect(r.type, 'reward');
        expect(r.count, 1);
        expect(r.ext, isNull);
      }
      expect(rewards, hasLength(3));
    });

    test('loadAd sends the impression config and controls', () async {
      final ad = PrebidRewardedAd(
        configId: 'r',
        impOrtbConfig: '{}',
        controls: const PrebidFullscreenControls(isMuted: true),
      );
      await ad.loadAd();
      final c =
          verify(api.loadAd(any, 'r', '{}', captureAny)).captured.single
              as FullscreenControlsConfig;
      expect(c.isMuted, isTrue);
    });

    test('destroy unregisters, loadAd re-registers', () async {
      final events = <String>[];
      final ad = PrebidRewardedAd(
        configId: 'r',
        listener: PrebidRewardedAdListener(
          onAdLoaded: () => events.add('loaded'),
        ),
      );
      final id = await load(ad);

      await ad.destroy();
      verify(api.destroy(id)).called(1);
      await _emit(id, 'onAdLoaded');
      expect(events, isEmpty);

      await load(ad);
      await _emit(id, 'onAdLoaded');
      expect(events, ['loaded']);
    });
  });

  group('PrebidNativeAd events', () {
    late MockNativeAdHostApi api;

    setUp(() {
      api = MockNativeAdHostApi();
      PrebidNativeAd.api = api;
    });

    Future<int> load(PrebidNativeAd ad) async {
      await ad.loadAd();
      return verify(api.loadAd(captureAny, any)).captured.last as int;
    }

    test('every event name reaches the listener', () async {
      final events = <String>[];
      final ad = PrebidNativeAd(
        configId: 'n',
        listener: PrebidNativeAdListener(
          onAdLoaded: (r) => events.add('loaded:${r.title}'),
          onAdFailed: (e) => events.add('failed:$e'),
          onAdImpression: () => events.add('impression'),
          onAdClicked: () => events.add('clicked'),
          onAdExpired: () => events.add('expired'),
        ),
      );
      final id = await load(ad);

      await AdEventRouter.instance.onAdEvent(
        AdEvent(
          adId: id,
          eventName: 'onAdLoaded',
          nativeAd: NativeAdData(title: 'T'),
        ),
      );
      // A load event without data is ignored.
      await _emit(id, 'onAdLoaded');
      await _emit(id, 'onAdFailed', error: 'boom');
      await _emit(id, 'onAdFailed');
      await _emit(id, 'onAdImpression');
      await _emit(id, 'onAdClicked');
      await _emit(id, 'onAdExpired');
      await _emit(id, 'onUnknown');

      expect(events, [
        'loaded:T',
        'failed:boom',
        'failed:Unknown error',
        'impression',
        'clicked',
        'expired',
      ]);
    });

    test('NativeAdData maps to PrebidNativeAdResponse', () async {
      PrebidNativeAdResponse? response;
      final ad = PrebidNativeAd(
        configId: 'n',
        listener: PrebidNativeAdListener(onAdLoaded: (r) => response = r),
      );
      final id = await load(ad);

      await AdEventRouter.instance.onAdEvent(
        AdEvent(
          adId: id,
          eventName: 'onAdLoaded',
          nativeAd: NativeAdData(
            title: 'Title',
            text: 'Body',
            iconUrl: 'icon',
            imageUrl: 'image',
            sponsoredBy: 'Brand',
            callToAction: 'Install',
            clickUrl: 'click',
            privacyUrl: 'privacy',
          ),
        ),
      );

      final r = response!;
      expect(r.title, 'Title');
      expect(r.text, 'Body');
      expect(r.iconUrl, 'icon');
      expect(r.imageUrl, 'image');
      expect(r.sponsoredBy, 'Brand');
      expect(r.callToAction, 'Install');
      expect(r.clickUrl, 'click');
      expect(r.privacyUrl, 'privacy');
      expect(r.titles, isEmpty);
      expect(r.images, isEmpty);
      expect(r.dataAssets, isEmpty);
      expect(r.dataOf(NativeDataType.rating), isEmpty);
    });

    test('loadAd sends the default assets when none are set', () async {
      final ad = PrebidNativeAd(
        configId: 'n',
        eventTrackers: const [
          NativeEventTracker(
            eventType: NativeEventType.impression,
            methods: [NativeEventTrackingMethod.image],
          ),
        ],
        context: NativeContextType.product,
        placementType: NativePlacementType.atomicUnit,
        placementCount: 2,
        pbAdSlot: '/slot',
        gpid: '/gpid',
        impOrtbConfig: '{}',
      );
      await ad.loadAd();
      final c =
          verify(api.loadAd(any, captureAny)).captured.single
              as NativeAdRequestConfig;
      expect(c.configId, 'n');
      final assets = c.assets!;
      expect(assets, hasLength(PrebidNativeAd.defaultAssets.length));
      expect(assets.first?.assetType, 'title');
      expect(assets.first?.required_, isTrue);
      expect(assets.first?.titleLength, 90);
      expect(c.eventTrackers?.single?.eventType, 1);
      expect(c.eventTrackers?.single?.methods, [1]);
      expect(c.context, 3);
      expect(c.placementType, 2);
      expect(c.placementCount, 2);
      expect(c.pbAdSlot, '/slot');
      expect(c.gpid, '/gpid');
      expect(c.impOrtbConfig, '{}');
    });

    test('destroy unregisters, loadAd re-registers', () async {
      final events = <String>[];
      final ad = PrebidNativeAd(
        configId: 'n',
        listener: PrebidNativeAdListener(
          onAdClicked: () => events.add('clicked'),
        ),
      );
      final id = await load(ad);

      await ad.destroy();
      verify(api.destroy(id)).called(1);
      await _emit(id, 'onAdClicked');
      expect(events, isEmpty);

      await load(ad);
      await _emit(id, 'onAdClicked');
      expect(events, ['clicked']);
    });
  });

  group('AdEventRouter', () {
    test('events for unknown ad ids are dropped', () async {
      await _emit(-42, 'onAdLoaded');
    });

    test('register is idempotent and unregister removes the handler', () async {
      final seen = <String>[];
      AdEventRouter.instance.register(-1, (e) => seen.add('a'));
      AdEventRouter.instance.register(-1, (e) => seen.add('b'));
      await _emit(-1, 'x');
      AdEventRouter.instance.unregister(-1);
      await _emit(-1, 'x');
      expect(seen, ['b']);
    });
  });

  group('Multiformat auto-refresh routing', () {
    late MockMultiformatAdHostApi api;

    setUp(() {
      api = MockMultiformatAdHostApi();
      PrebidMultiformatAd.api = api;
      when(api.fetchDemand(any, any)).thenAnswer(
        (_) async => MultiformatBidResult(resultCode: 'prebidDemandNoBids'),
      );
    });

    Future<int> lastAdId() async =>
        verify(api.fetchDemand(captureAny, any)).captured.last as int;

    Future<void> refresh(int adId, String code) =>
        MultiformatEventRouter.instance.onDemandRefreshed(
          adId,
          MultiformatBidResult(
            resultCode: code,
            winningFormat: 'banner',
            targetingKeywords: {'hb_pb': '1.00', 'drop': null, null: 'x'},
          ),
        );

    test('refreshed results reach onDemandRefreshed', () async {
      final results = <PrebidMultiformatBidResponse>[];
      final ad = PrebidMultiformatAd(
        configId: 'm',
        bannerSizes: const [Size(320, 50)],
        onDemandRefreshed: results.add,
      );
      await ad.fetchDemand();
      final id = await lastAdId();

      await refresh(id, 'prebidDemandFetchSuccess');
      expect(results.single.isSuccess, isTrue);
      expect(results.single.winningFormat, 'banner');
      expect(results.single.targetingKeywords, {'hb_pb': '1.00'});
    });

    test('destroy then fetchDemand delivers refreshes again', () async {
      final results = <PrebidMultiformatBidResponse>[];
      final ad = PrebidMultiformatAd(
        configId: 'm',
        bannerSizes: const [Size(320, 50)],
        onDemandRefreshed: results.add,
      );
      await ad.fetchDemand();
      final id = await lastAdId();

      await ad.destroy();
      verify(api.destroy(id)).called(1);
      await refresh(id, 'prebidDemandFetchSuccess');
      expect(results, isEmpty);

      await ad.fetchDemand();
      await refresh(id, 'prebidDemandFetchSuccess');
      expect(results, hasLength(1));
    });

    test('Original API units deliver refreshes again after destroy', () async {
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
        assets: const [NativeAsset.title()],
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

      for (final (fetchDemand, destroy, received) in units) {
        await fetchDemand();
        final id = await lastAdId();
        await destroy();
        await refresh(id, 'prebidDemandFetchSuccess');
        expect(received, isEmpty);

        await fetchDemand();
        await refresh(id, 'prebidDemandFetchSuccess');
        expect(received, hasLength(1));
      }
      expect(banner.single.targetingKeywords, {'hb_pb': '1.00'});
      expect(native.single.isSuccess, isTrue);
    });
  });
}
