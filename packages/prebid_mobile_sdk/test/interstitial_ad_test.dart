import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

import 'mock_host_api.mocks.dart';
import 'platform_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockInterstitialAdHostApi api;

  setUp(() {
    api = MockInterstitialAdHostApi();
    PrebidInterstitialAd.api = api;
  });

  /// The arguments of the last `loadAd`.
  List<Object?> lastLoad() => verify(
    api.loadAd(
      captureAny,
      captureAny,
      captureAny,
      captureAny,
      captureAny,
      captureAny,
      captureAny,
      captureAny,
      captureAny,
    ),
  ).captured;

  Future<int> load(PrebidInterstitialAd ad) async {
    await ad.loadAd();
    return lastLoad()[0]! as int;
  }

  Future<void> send(int adId, String event, {String? error}) =>
      sendAdEvent(AdEvent(adId: adId, eventName: event, error: error));

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

  group('loadAd', () {
    test('sends the whole request', () async {
      await PrebidInterstitialAd(
        configId: 'i',
        adFormats: {PrebidAdFormat.banner, PrebidAdFormat.video},
        videoParameters: const VideoParameters(
          mimes: ['video/mp4'],
          protocols: [VideoProtocol.vast2_0, VideoProtocol.vast4_0Wrapper],
          playbackMethods: [VideoPlaybackMethod.clickToPlay],
          placement: VideoPlacement.inFeed,
          maxDuration: 60,
          minDuration: 5,
          api: [VideoApi.mraid3, VideoApi.omid1],
          plcmt: VideoPlcmt.interstitial,
          startDelay: VideoStartDelay.preRoll,
          linearity: VideoLinearity.nonLinear,
          skippable: false,
          battr: [VideoCreativeAttribute.flash],
          minBitrate: 1,
          maxBitrate: 2,
          size: Size(640, 480),
        ),
        impOrtbConfig: '{"instl":1}',
        globalOrtbConfig: '{"app":{}}',
        pbAdSlot: '/slot',
        adPosition: PrebidAdPosition.fullScreen,
        controls: const PrebidFullscreenControls(
          closeButtonArea: 0.1,
          closeButtonPosition: PrebidButtonPosition.topLeft,
          skipButtonArea: 0.2,
          skipButtonPosition: PrebidButtonPosition.topRight,
          skipDelay: 4,
          isMuted: false,
          isSoundButtonVisible: true,
          isAutoCloseOnCompletionEnabled: true,
          minSizePercentage: Size(49.6, 70.2),
          supportSKOverlay: false,
        ),
      ).loadAd();

      final args = lastLoad();
      expect(args[1], 'i');
      expect(args[2], ['banner', 'video']);
      final video = args[3]! as VideoParametersConfig;
      expect(video.mimes, ['video/mp4']);
      expect(video.protocols, [2, 8]);
      expect(video.playbackMethods, [3]);
      expect(video.placement, 4);
      expect((video.maxDuration, video.minDuration), (60, 5));
      expect(video.api, [6, 7]);
      expect(video.plcmt, 3);
      expect(video.startDelay, 0);
      expect(video.linearity, 2);
      expect(video.skippable, isFalse);
      expect(video.battr, [17]);
      expect((video.minBitrate, video.maxBitrate), (1, 2));
      expect((video.width, video.height), (640, 480));
      expect(args[4], '{"instl":1}');
      expect(args[5], '{"app":{}}');
      final controls = args[6]! as FullscreenControlsConfig;
      expect(controls.closeButtonArea, 0.1);
      expect(controls.closeButtonPosition, 'topLeft');
      expect(controls.skipButtonArea, 0.2);
      expect(controls.skipButtonPosition, 'topRight');
      expect(controls.skipDelay, 4);
      expect(controls.isMuted, isFalse);
      expect(controls.isSoundButtonVisible, isTrue);
      expect(controls.isAutoCloseOnCompletionEnabled, isTrue);
      // Whole percents, rounded.
      expect(
        (controls.minWidthPercentage, controls.minHeightPercentage),
        (50, 70),
      );
      expect(controls.supportSKOverlay, isFalse);
      expect(args[7], '/slot');
      expect(args[8], 7);
    });

    test('leaves every unset option out', () async {
      await PrebidInterstitialAd(configId: 'i').loadAd();
      expect(lastLoad().skip(1), [
        'i',
        null,
        null,
        null,
        null,
        null,
        null,
        null,
      ]);
    });

    test('unset video fields and controls stay unset', () async {
      await PrebidInterstitialAd(
        configId: 'i',
        videoParameters: const VideoParameters(mimes: []),
        controls: const PrebidFullscreenControls(skipDelay: 3),
      ).loadAd();
      final args = lastLoad();
      final video = args[3]! as VideoParametersConfig;
      expect((video.protocols, video.plcmt, video.battr), (null, null, null));
      final controls = args[6]! as FullscreenControlsConfig;
      expect(controls.skipDelay, 3);
      expect((controls.isMuted, controls.minWidthPercentage), (null, null));
    });
  });

  group('the GPID', () {
    Future<Object?> sentImpOrtb(String? impOrtbConfig) async {
      await PrebidInterstitialAd(
        configId: 'c',
        gpid: '/1/home',
        impOrtbConfig: impOrtbConfig,
      ).loadAd();
      final imp = lastLoad()[4] as String?;
      try {
        return jsonDecode(imp!);
      } on FormatException {
        return imp;
      }
    }

    test('becomes imp.ext.gpid without an impression config', () async {
      expect(await sentImpOrtb(null), {
        'ext': {'gpid': '/1/home'},
      });
    });

    test('joins the impression config, keeping its keys', () async {
      expect(await sentImpOrtb('{"instl":1,"ext":{"data":{"k":"v"}}}'), {
        'instl': 1,
        'ext': {
          'gpid': '/1/home',
          'data': {'k': 'v'},
        },
      });
    });

    test('gives way to a gpid the impression config sets', () async {
      expect(await sentImpOrtb('{"ext":{"gpid":"/1/own"}}'), {
        'ext': {'gpid': '/1/own'},
      });
    });

    test('leaves an impression config that is not JSON alone', () async {
      expect(await sentImpOrtb('not json'), 'not json');
    });
  });

  group('events', () {
    test('each one reaches its callback', () async {
      final events = <String>[];
      final ad = PrebidInterstitialAd(
        configId: 'i',
        listener: recorder(events),
      );
      final id = await load(ad);

      await send(id, 'onAdLoaded');
      await send(id, 'onAdFailed', error: 'boom');
      await send(id, 'onAdFailed');
      await send(id, 'onAdDisplayed');
      await send(id, 'onAdClosed');
      await send(id, 'onAdClicked');
      await send(id, 'onAdExpired');
      await send(id, 'onAdImpression');
      await send(id, 'onUnknown');

      expect(events, [
        'loaded',
        'failed:boom',
        'failed:Unknown error',
        'displayed',
        'closed',
        'clicked',
        'expired',
        'impression',
      ]);
    });

    test('reach only the ad they belong to', () async {
      final a = <String>[];
      final b = <String>[];
      final adA = PrebidInterstitialAd(configId: 'a', listener: recorder(a));
      final adB = PrebidInterstitialAd(configId: 'b', listener: recorder(b));
      final idA = await load(adA);
      final idB = await load(adB);

      await send(idA, 'onAdLoaded');
      await send(idB, 'onAdClicked');
      expect(a, ['loaded']);
      expect(b, ['clicked']);
    });

    test('stop after destroy and come back with the next load', () async {
      final events = <String>[];
      final ad = PrebidInterstitialAd(
        configId: 'i',
        listener: recorder(events),
      );
      final id = await load(ad);

      await ad.destroy();
      verify(api.destroy(id)).called(1);
      await send(id, 'onAdLoaded');
      expect(events, isEmpty);

      expect(await load(ad), id);
      await send(id, 'onAdLoaded');
      expect(events, ['loaded']);
    });
  });

  group('isLoaded', () {
    test('is true from onAdLoaded until shown', () async {
      final ad = PrebidInterstitialAd(configId: 'i');
      expect(ad.isLoaded, isFalse);
      final id = await load(ad);
      expect(ad.isLoaded, isFalse);

      await send(id, 'onAdLoaded');
      expect(ad.isLoaded, isTrue);
      await ad.show();
      verify(api.show(id)).called(1);
      expect(ad.isLoaded, isFalse);
    });

    test('turns false on a failure, a close or an expiry', () async {
      final ad = PrebidInterstitialAd(configId: 'i');
      final id = await load(ad);
      for (final event in ['onAdFailed', 'onAdClosed', 'onAdExpired']) {
        await send(id, 'onAdLoaded');
        await send(id, event);
        expect(ad.isLoaded, isFalse, reason: event);
      }
    });

    test('turns false on destroy and on a reload', () async {
      final ad = PrebidInterstitialAd(configId: 'i');
      final id = await load(ad);
      await send(id, 'onAdLoaded');
      await ad.loadAd();
      expect(ad.isLoaded, isFalse);

      await send(id, 'onAdLoaded');
      await ad.destroy();
      expect(ad.isLoaded, isFalse);
    });
  });

  group('winningBid', () {
    test('is the bid of the loaded event', () async {
      final ad = PrebidInterstitialAd(configId: 'c');
      final id = await load(ad);
      await sendAdEvent(
        AdEvent(
          adId: id,
          eventName: 'onAdLoaded',
          winningBid: WinningBidData(
            price: 1.25,
            bidder: 'appnexus',
            width: 320,
            height: 480,
            targetingKeywords: {'hb_pb': '1.20'},
          ),
        ),
      );
      final bid = ad.winningBid!;
      expect(bid.price, 1.25);
      expect(bid.bidder, 'appnexus');
      expect(bid.size, const Size(320, 480));
      expect(bid.targetingKeywords, {'hb_pb': '1.20'});
    });

    test('is null before a load and when the platform sends none', () async {
      final ad = PrebidInterstitialAd(configId: 'c');
      expect(ad.winningBid, isNull);
      final id = await load(ad);
      await send(id, 'onAdLoaded');
      expect(ad.winningBid, isNull);
    });
  });

  test('a platform error from show reaches the caller', () async {
    when(
      api.show(any),
    ).thenThrow(PlatformException(code: 'error', message: 'boom'));
    final ad = PrebidInterstitialAd(configId: 'i');
    await expectLater(ad.show(), throwsA(isA<PlatformException>()));
  });
}
