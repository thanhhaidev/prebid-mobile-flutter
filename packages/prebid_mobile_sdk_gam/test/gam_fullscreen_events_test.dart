import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';

import 'channel_harness.dart';

const _interstitialChannel = 'prebid_mobile_sdk_gam/interstitial';
const _rewardedChannel = 'prebid_mobile_sdk_gam/rewarded';

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

  group('PrebidGamInterstitialAd', () {
    test('minimal load sends exactly adId, ids and default formats', () async {
      final h = ChannelHarness(_interstitialChannel);
      await PrebidGamInterstitialAd(configId: 'c', gamAdUnitId: 'u').loadAd();

      final call = h.calls.single;
      expect(call.method, 'load');
      final args = call.arguments as Map;
      expect(
        args.keys,
        unorderedEquals(['adId', 'configId', 'gamAdUnitId', 'adFormats']),
      );
      expect(args['adId'], isA<int>());
      expect(args['configId'], 'c');
      expect(args['gamAdUnitId'], 'u');
      expect(args['adFormats'], isNull); // native side defaults to banner
    });

    test('sends every format name', () async {
      final h = ChannelHarness(_interstitialChannel);
      await PrebidGamInterstitialAd(
        configId: 'c',
        gamAdUnitId: 'u',
        adFormats: {AdFormat.banner, AdFormat.video},
      ).loadAd();
      expect(
        h.argsOf('load')['adFormats'],
        unorderedEquals(['banner', 'video']),
      );
    });

    test('show and destroy send only the adId', () async {
      final h = ChannelHarness(_interstitialChannel);
      final ad = PrebidGamInterstitialAd(configId: 'c', gamAdUnitId: 'u');
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
      final ad = PrebidGamInterstitialAd(
        configId: 'c',
        gamAdUnitId: 'u',
        listener: _interstitialListener(fired),
      );
      await ad.loadAd();
      final adId = h.argsOf('load')['adId'] as int;

      await h.emit('onAdLoaded', adId);
      expect(ad.isLoaded, isTrue);
      await h.emit('onAdDisplayed', adId);
      await h.emit('onAdClicked', adId);
      await h.emit('onAdClosed', adId);
      expect(ad.isLoaded, isFalse);
      await h.emit('onAdFailed', adId, {'error': 'no fill'});
      await h.emit('onAdFailed', adId); // no error key
      await h.emit('onAdLoaded', adId);
      await h.emit('onAdExpired', adId);
      expect(ad.isLoaded, isFalse);
      await h.emit('onSomethingElse', adId); // unknown: ignored

      expect(fired, [
        'loaded',
        'displayed',
        'clicked',
        'closed',
        'failed:no fill',
        'failed:',
        'loaded',
        'expired',
      ]);
    });

    test('a load without an Activity fails through the listener', () async {
      final h = ChannelHarness(_interstitialChannel);
      final fired = <String>[];
      final ad = PrebidGamInterstitialAd(
        configId: 'c',
        gamAdUnitId: 'u',
        listener: _interstitialListener(fired),
      );
      // The native side answers the call and reports the failure as an event
      // (no PlatformException), as on iOS.
      await expectLater(ad.loadAd(), completes);
      await h.emit('onAdFailed', h.argsOf('load')['adId'] as int, {
        'error': 'No attached Activity to load the interstitial',
      });
      expect(fired, ['failed:No attached Activity to load the interstitial']);
      expect(ad.isLoaded, isFalse);
    });

    test('events without an adId or for other ads are ignored', () async {
      final h = ChannelHarness(_interstitialChannel);
      final fired = <String>[];
      final a = PrebidGamInterstitialAd(
        configId: 'c',
        gamAdUnitId: 'u',
        listener: _interstitialListener(fired),
      );
      final b = PrebidGamInterstitialAd(configId: 'c', gamAdUnitId: 'u');
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
      final ad = PrebidGamInterstitialAd(
        configId: 'c',
        gamAdUnitId: 'u',
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
      expect(h.argsOf('load')['adId'], adId); // same ad, same id
      await h.emit('onAdLoaded', adId);
      expect(fired, ['loaded', 'loaded']);
      expect(ad.isLoaded, isTrue);
    });
  });

  group('PrebidGamRewardedAd', () {
    test('minimal load sends exactly adId and ids', () async {
      final h = ChannelHarness(_rewardedChannel);
      await PrebidGamRewardedAd(configId: 'c', gamAdUnitId: 'u').loadAd();
      final args = h.argsOf('load');
      expect(args.keys, unorderedEquals(['adId', 'configId', 'gamAdUnitId']));
      expect(args['configId'], 'c');
      expect(args['gamAdUnitId'], 'u');
    });

    test('full load sends targeting, controls, ORTB and video', () async {
      final h = ChannelHarness(_rewardedChannel);
      await PrebidGamRewardedAd(
        configId: 'c',
        gamAdUnitId: 'u',
        customTargeting: const {'k': 'v'},
        controls: const PrebidFullscreenControls(skipDelay: 3),
        impOrtbConfig: '{}',
        videoParameters: const VideoParameters(mimes: ['video/mp4']),
      ).loadAd();
      final args = h.argsOf('load');
      expect(
        args.keys,
        unorderedEquals([
          'adId',
          'configId',
          'gamAdUnitId',
          'customTargeting',
          'controls',
          'impOrtbConfig',
          'videoParameters',
        ]),
      );
      expect(args['customTargeting'], {'k': 'v'});
      expect(args['controls'], {'skipDelay': 3});
      expect(args['impOrtbConfig'], '{}');
      expect(args['videoParameters'], {
        'mimes': ['video/mp4'],
      });
    });

    test('show and destroy send only the adId', () async {
      final h = ChannelHarness(_rewardedChannel);
      final ad = PrebidGamRewardedAd(configId: 'c', gamAdUnitId: 'u');
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
      final ad = PrebidGamRewardedAd(
        configId: 'c',
        gamAdUnitId: 'u',
        listener: _rewardedListener(fired),
      );
      await ad.loadAd();
      final adId = h.argsOf('load')['adId'] as int;

      for (final e in [
        'onAdLoaded',
        'onAdDisplayed',
        'onAdClicked',
        'onUserEarnedReward',
        'onAdClosed',
      ]) {
        await h.emit(e, adId);
      }
      await h.emit('onAdFailed', adId, {'error': 'boom'});
      await h.emit('onAdExpired', adId);
      expect(fired, [
        'loaded',
        'displayed',
        'clicked',
        'reward',
        'closed',
        'failed:boom',
        'expired',
      ]);
    });

    test('rewards keep type, count and ext; bad ext is dropped', () async {
      final h = ChannelHarness(_rewardedChannel);
      final rewards = <PrebidReward>[];
      final ad = PrebidGamRewardedAd(
        configId: 'c',
        gamAdUnitId: 'u',
        listener: _rewardedListener([], rewards),
      );
      await ad.loadAd();
      final adId = h.argsOf('load')['adId'] as int;

      await h.emit('onUserEarnedReward', adId, {
        'rewardType': 'gems',
        'rewardCount': 2.0, // a num from the platform still maps
        'rewardExt': {'tier': 1}, // already a map
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
      final ad = PrebidGamRewardedAd(
        configId: 'c',
        gamAdUnitId: 'u',
        listener: _rewardedListener(fired),
      );
      await expectLater(ad.loadAd(), completes);
      await h.emit('onAdFailed', h.argsOf('load')['adId'] as int, {
        'error': 'No attached Activity to load the rewarded ad',
      });
      expect(fired, ['failed:No attached Activity to load the rewarded ad']);
      expect(ad.isLoaded, isFalse);
    });

    test('destroy stops events; a reload routes them again', () async {
      final h = ChannelHarness(_rewardedChannel);
      final fired = <String>[];
      final ad = PrebidGamRewardedAd(
        configId: 'c',
        gamAdUnitId: 'u',
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
