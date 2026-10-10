import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';

import 'channel_harness.dart';

const _interstitialChannel = 'prebid_mobile_sdk_admob/interstitial';
const _rewardedChannel = 'prebid_mobile_sdk_admob/rewarded';

PrebidInterstitialAdListener _interstitialListener(List<String> fired) =>
    PrebidInterstitialAdListener(
      onAdLoaded: () => fired.add('loaded'),
      onAdFailed: (e) => fired.add('failed:$e'),
      onAdDisplayed: () => fired.add('displayed'),
      onAdClosed: () => fired.add('closed'),
      onAdClicked: () => fired.add('clicked'),
      onAdExpired: () => fired.add('expired'),
      onAdImpression: () => fired.add('impression'),
    );

PrebidRewardedAdListener _rewardedListener(
  List<String> fired, [
  List<PrebidReward>? rewards,
]) => PrebidRewardedAdListener(
  onAdLoaded: () => fired.add('loaded'),
  onAdFailed: (e) => fired.add('failed:$e'),
  onAdDisplayed: () => fired.add('displayed'),
  onAdClosed: () => fired.add('closed'),
  onAdClicked: () => fired.add('clicked'),
  onAdExpired: () => fired.add('expired'),
  onAdImpression: () => fired.add('impression'),
  onUserEarnedReward: (r) {
    fired.add('reward');
    rewards?.add(r);
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrebidAdMobInterstitialAd', () {
    test('minimal load sends exactly adId, ids and the video flag', () async {
      final h = ChannelHarness(_interstitialChannel);
      await PrebidAdMobInterstitialAd(
        configId: 'c',
        adMobAdUnitId: 'u',
      ).loadAd();

      final call = h.calls.single;
      expect(call.method, 'load');
      final args = call.arguments as Map;
      expect(
        args.keys,
        unorderedEquals(['adId', 'configId', 'adMobAdUnitId', 'isVideo']),
      );
      expect(args['adId'], isA<int>());
      expect(args['configId'], 'c');
      expect(args['adMobAdUnitId'], 'u');
      expect(args['isVideo'], isFalse);
    });

    test('full load sends controls, ORTB, slot and video', () async {
      final h = ChannelHarness(_interstitialChannel);
      await PrebidAdMobInterstitialAd(
        configId: 'c',
        adMobAdUnitId: 'u',
        isVideo: true,
        controls: const PrebidFullscreenControls(
          isMuted: false,
          minSizePercentage: Size(50, 70),
        ),
        impOrtbConfig: '{}',
        globalOrtbConfig: '{"app":{}}',
        pbAdSlot: '/slot',
        videoParameters: const VideoParameters(
          mimes: ['video/mp4'],
          protocols: [VideoProtocol.vast4_0],
          plcmt: VideoPlcmt.interstitial,
          skippable: false,
          maxDuration: 15,
        ),
      ).loadAd();
      expect(h.argsOf('load')..remove('adId'), {
        'configId': 'c',
        'adMobAdUnitId': 'u',
        'isVideo': true,
        'controls': {
          'isMuted': false,
          'minWidthPercentage': 50,
          'minHeightPercentage': 70,
        },
        'impOrtbConfig': '{}',
        'globalOrtbConfig': '{"app":{}}',
        'pbAdSlot': '/slot',
        'videoParameters': {
          'mimes': ['video/mp4'],
          'protocols': [7],
          'maxDuration': 15,
          'plcmt': 3,
          'skippable': false,
        },
      });
    });

    test('show and destroy send only the adId', () async {
      final h = ChannelHarness(_interstitialChannel);
      final ad = PrebidAdMobInterstitialAd(configId: 'c', adMobAdUnitId: 'u');
      await ad.loadAd();
      final adId = h.argsOf('load')['adId'];

      await ad.show();
      expect(h.calls.last.method, 'show');
      expect(h.calls.last.arguments, {'adId': adId});
      await ad.destroy();
      expect(h.calls.last.method, 'destroy');
      expect(h.calls.last.arguments, {'adId': adId});
    });

    test('every event reaches its callback', () async {
      final h = ChannelHarness(_interstitialChannel);
      final fired = <String>[];
      final ad = PrebidAdMobInterstitialAd(
        configId: 'c',
        adMobAdUnitId: 'u',
        listener: _interstitialListener(fired),
      );
      await ad.loadAd();
      final adId = h.argsOf('load')['adId'] as int;

      await h.emit('onAdLoaded', adId);
      expect(ad.isLoaded, isTrue);
      await h.emit('onAdDisplayed', adId);
      await h.emit('onAdImpression', adId);
      await h.emit('onAdClicked', adId);
      await h.emit('onAdClosed', adId);
      expect(ad.isLoaded, isFalse);
      await h.emit('onAdFailed', adId, {'error': 'no fill'});
      await h.emit('onAdFailed', adId); // no error key
      await h.emit('onSomethingElse', adId); // unknown: ignored

      expect(fired, [
        'loaded',
        'displayed',
        'impression',
        'clicked',
        'closed',
        'failed:no fill',
        'failed:Unknown error',
      ]);
    });

    test('a load without an Activity fails through the listener', () async {
      final h = ChannelHarness(_interstitialChannel);
      final fired = <String>[];
      final ad = PrebidAdMobInterstitialAd(
        configId: 'c',
        adMobAdUnitId: 'u',
        listener: _interstitialListener(fired),
      );
      // The native side answers the call and reports the failure as an event
      // (no PlatformException), as on iOS.
      await expectLater(ad.loadAd(), completes);
      await h.emit('onAdFailed', h.argsOf('load')['adId'] as int, {
        'error': 'No Activity is attached to the Flutter engine',
      });
      expect(fired, ['failed:No Activity is attached to the Flutter engine']);
      expect(ad.isLoaded, isFalse);
    });

    test('events without an adId or for other ads are ignored', () async {
      final h = ChannelHarness(_interstitialChannel);
      final fired = <String>[];
      final a = PrebidAdMobInterstitialAd(
        configId: 'c',
        adMobAdUnitId: 'u',
        listener: _interstitialListener(fired),
      );
      final b = PrebidAdMobInterstitialAd(configId: 'c', adMobAdUnitId: 'u');
      await a.loadAd();
      final aId = h.argsOf('load')['adId'] as int;
      await b.loadAd();
      final bId = h.argsOf('load')['adId'] as int;
      expect(aId, isNot(bId));

      await h.emit('onAdLoaded', bId);
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            _interstitialChannel,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onAdLoaded'),
            ),
            (_) {},
          );
      expect(fired, isEmpty);
      expect(b.isLoaded, isTrue);
      expect(a.isLoaded, isFalse);
    });

    test('destroy stops events; a reload routes them again', () async {
      final h = ChannelHarness(_interstitialChannel);
      final fired = <String>[];
      final ad = PrebidAdMobInterstitialAd(
        configId: 'c',
        adMobAdUnitId: 'u',
        listener: _interstitialListener(fired),
      );
      await ad.loadAd();
      final adId = h.argsOf('load')['adId'] as int;
      await h.emit('onAdLoaded', adId);
      await ad.destroy();
      expect(ad.isLoaded, isFalse);
      await h.emit('onAdClosed', adId);
      expect(fired, ['loaded']);

      await ad.loadAd();
      expect(h.calls.map((c) => c.method), ['load', 'destroy', 'load']);
      expect(h.argsOf('load')['adId'], adId);
      await h.emit('onAdLoaded', adId);
      expect(fired, ['loaded', 'loaded']);
      expect(ad.isLoaded, isTrue);
    });
  });

  group('PrebidAdMobRewardedAd', () {
    test('minimal load sends exactly adId and ids', () async {
      final h = ChannelHarness(_rewardedChannel);
      await PrebidAdMobRewardedAd(configId: 'c', adMobAdUnitId: 'u').loadAd();
      final args = h.argsOf('load');
      expect(args.keys, unorderedEquals(['adId', 'configId', 'adMobAdUnitId']));
      expect(args['configId'], 'c');
      expect(args['adMobAdUnitId'], 'u');
    });

    test('full load sends controls, ORTB, slot and video', () async {
      final h = ChannelHarness(_rewardedChannel);
      await PrebidAdMobRewardedAd(
        configId: 'c',
        adMobAdUnitId: 'u',
        controls: const PrebidFullscreenControls(skipDelay: 3),
        impOrtbConfig: '{}',
        globalOrtbConfig: '{"app":{}}',
        pbAdSlot: '/slot',
        videoParameters: const VideoParameters(
          mimes: ['video/mp4'],
          battr: [VideoCreativeAttribute.adCanBeSkipped],
          maxBitrate: 2000,
        ),
      ).loadAd();
      expect(h.argsOf('load')..remove('adId'), {
        'configId': 'c',
        'adMobAdUnitId': 'u',
        'controls': {'skipDelay': 3},
        'impOrtbConfig': '{}',
        'globalOrtbConfig': '{"app":{}}',
        'pbAdSlot': '/slot',
        'videoParameters': {
          'mimes': ['video/mp4'],
          'battr': [16],
          'maxBitrate': 2000,
        },
      });
    });

    test('isLoaded resets on show, close, failure and destroy', () async {
      final h = ChannelHarness(_rewardedChannel);
      final ad = PrebidAdMobRewardedAd(configId: 'c', adMobAdUnitId: 'u');
      await ad.loadAd();
      final adId = h.argsOf('load')['adId'] as int;

      await h.emit('onAdLoaded', adId);
      expect(ad.isLoaded, isTrue);
      await ad.show();
      expect(ad.isLoaded, isFalse);
      for (final end in ['onAdClosed', 'onAdFailed']) {
        await h.emit('onAdLoaded', adId);
        await h.emit(end, adId);
        expect(ad.isLoaded, isFalse, reason: end);
      }
      await h.emit('onAdLoaded', adId);
      await ad.destroy();
      expect(ad.isLoaded, isFalse);
    });

    test('show and destroy send only the adId', () async {
      final h = ChannelHarness(_rewardedChannel);
      final ad = PrebidAdMobRewardedAd(configId: 'c', adMobAdUnitId: 'u');
      await ad.loadAd();
      final adId = h.argsOf('load')['adId'];
      await ad.show();
      expect(h.calls.last.method, 'show');
      expect(h.calls.last.arguments, {'adId': adId});
      await ad.destroy();
      expect(h.calls.last.method, 'destroy');
      expect(h.calls.last.arguments, {'adId': adId});
    });

    test('every event reaches its callback', () async {
      final h = ChannelHarness(_rewardedChannel);
      final fired = <String>[];
      final ad = PrebidAdMobRewardedAd(
        configId: 'c',
        adMobAdUnitId: 'u',
        listener: _rewardedListener(fired),
      );
      await ad.loadAd();
      final adId = h.argsOf('load')['adId'] as int;

      for (final e in [
        'onAdLoaded',
        'onAdDisplayed',
        'onAdImpression',
        'onAdClicked',
        'onUserEarnedReward',
        'onAdClosed',
        'onUnknown',
      ]) {
        await h.emit(e, adId);
      }
      await h.emit('onAdFailed', adId, {'error': 'boom'});
      expect(fired, [
        'loaded',
        'displayed',
        'impression',
        'clicked',
        'reward',
        'closed',
        'failed:boom',
      ]);
    });

    test('rewards keep type, count and ext; bad ext is dropped', () async {
      final h = ChannelHarness(_rewardedChannel);
      final rewards = <PrebidReward>[];
      final ad = PrebidAdMobRewardedAd(
        configId: 'c',
        adMobAdUnitId: 'u',
        listener: _rewardedListener([], rewards),
      );
      await ad.loadAd();
      final adId = h.argsOf('load')['adId'] as int;

      await h.emit('onUserEarnedReward', adId, {
        'rewardType': 'gems',
        'rewardCount': 2.0,
        'rewardExt': {'tier': 1},
      });
      await h.emit('onUserEarnedReward', adId, {
        'rewardType': 'coins',
        'rewardCount': 5,
        'rewardExt': 'not json',
      });
      await h.emit('onUserEarnedReward', adId, {'rewardExt': '[1, 2]'});
      expect(rewards.map((r) => [r.type, r.count, r.ext]), [
        [
          'gems',
          2,
          {'tier': 1},
        ],
        ['coins', 5, null],
        ['reward', 1, null],
      ]);
    });

    test('a load without an Activity fails through the listener', () async {
      final h = ChannelHarness(_rewardedChannel);
      final fired = <String>[];
      final ad = PrebidAdMobRewardedAd(
        configId: 'c',
        adMobAdUnitId: 'u',
        listener: _rewardedListener(fired),
      );
      await expectLater(ad.loadAd(), completes);
      await h.emit('onAdFailed', h.argsOf('load')['adId'] as int, {
        'error': 'No Activity is attached to the Flutter engine',
      });
      expect(fired, ['failed:No Activity is attached to the Flutter engine']);
      expect(ad.isLoaded, isFalse);
    });

    test('destroy stops events; a reload routes them again', () async {
      final h = ChannelHarness(_rewardedChannel);
      final fired = <String>[];
      final ad = PrebidAdMobRewardedAd(
        configId: 'c',
        adMobAdUnitId: 'u',
        listener: _rewardedListener(fired),
      );
      await ad.loadAd();
      final adId = h.argsOf('load')['adId'] as int;
      await ad.destroy();
      await h.emit('onUserEarnedReward', adId);
      await h.emit('onAdLoaded', adId);
      expect(fired, isEmpty);

      await ad.loadAd();
      await h.emit('onAdLoaded', adId);
      expect(fired, ['loaded']);
      expect(ad.isLoaded, isTrue);
    });
  });
}
