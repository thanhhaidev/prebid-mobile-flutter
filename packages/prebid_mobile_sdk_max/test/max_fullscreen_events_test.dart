import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import 'channel_harness.dart';

const _interstitialChannel = 'prebid_mobile_sdk_max/interstitial';
const _rewardedChannel = 'prebid_mobile_sdk_max/rewarded';

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

  group('PrebidMaxInterstitialAd', () {
    test('minimal load sends exactly adId, ids and the video flag', () async {
      final h = ChannelHarness(_interstitialChannel);
      await PrebidMaxInterstitialAd(configId: 'c', maxAdUnitId: 'u').loadAd();

      final call = h.calls.single;
      expect(call.method, 'load');
      final args = call.arguments as Map;
      expect(
        args.keys,
        unorderedEquals(['adId', 'configId', 'maxAdUnitId', 'isVideo']),
      );
      expect(args['adId'], isA<int>());
      expect(args['configId'], 'c');
      expect(args['maxAdUnitId'], 'u');
      expect(args['isVideo'], isFalse);
    });

    test('full load sends controls, ORTB and video', () async {
      final h = ChannelHarness(_interstitialChannel);
      await PrebidMaxInterstitialAd(
        configId: 'c',
        maxAdUnitId: 'u',
        isVideo: true,
        controls: const PrebidFullscreenControls(isMuted: false),
        impOrtbConfig: '{}',
        videoParameters: const VideoParameters(
          mimes: ['video/mp4'],
          maxDuration: 15,
        ),
      ).loadAd();
      final args = h.argsOf('load');
      expect(args.keys, hasLength(7));
      expect(args['isVideo'], isTrue);
      expect(args['controls'], {'isMuted': false});
      expect(args['impOrtbConfig'], '{}');
      expect(args['videoParameters'], containsPair('maxDuration', 15));
    });

    test('show and destroy send only the adId', () async {
      final h = ChannelHarness(_interstitialChannel);
      final ad = PrebidMaxInterstitialAd(configId: 'c', maxAdUnitId: 'u');
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
      final ad = PrebidMaxInterstitialAd(
        configId: 'c',
        maxAdUnitId: 'u',
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
        'failed:',
      ]);
    });

    test('a load without an Activity fails through the listener', () async {
      final h = ChannelHarness(_interstitialChannel);
      final fired = <String>[];
      final ad = PrebidMaxInterstitialAd(
        configId: 'c',
        maxAdUnitId: 'u',
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
      final a = PrebidMaxInterstitialAd(
        configId: 'c',
        maxAdUnitId: 'u',
        listener: _interstitialListener(fired),
      );
      final b = PrebidMaxInterstitialAd(configId: 'c', maxAdUnitId: 'u');
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
      final ad = PrebidMaxInterstitialAd(
        configId: 'c',
        maxAdUnitId: 'u',
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

  group('PrebidMaxRewardedAd', () {
    test('minimal load sends exactly adId and ids', () async {
      final h = ChannelHarness(_rewardedChannel);
      await PrebidMaxRewardedAd(configId: 'c', maxAdUnitId: 'u').loadAd();
      final args = h.argsOf('load');
      expect(args.keys, unorderedEquals(['adId', 'configId', 'maxAdUnitId']));
      expect(args['configId'], 'c');
      expect(args['maxAdUnitId'], 'u');
    });

    test('full load sends controls, ORTB and video', () async {
      final h = ChannelHarness(_rewardedChannel);
      await PrebidMaxRewardedAd(
        configId: 'c',
        maxAdUnitId: 'u',
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
          'maxAdUnitId',
          'controls',
          'impOrtbConfig',
          'videoParameters',
        ]),
      );
      expect(args['controls'], {'skipDelay': 3});
      expect(args['impOrtbConfig'], '{}');
      expect(args['videoParameters'], {
        'mimes': ['video/mp4'],
      });
    });

    test('show and destroy send only the adId', () async {
      final h = ChannelHarness(_rewardedChannel);
      final ad = PrebidMaxRewardedAd(configId: 'c', maxAdUnitId: 'u');
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
      final ad = PrebidMaxRewardedAd(
        configId: 'c',
        maxAdUnitId: 'u',
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
      final ad = PrebidMaxRewardedAd(
        configId: 'c',
        maxAdUnitId: 'u',
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
      final ad = PrebidMaxRewardedAd(
        configId: 'c',
        maxAdUnitId: 'u',
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
      final ad = PrebidMaxRewardedAd(
        configId: 'c',
        maxAdUnitId: 'u',
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

    test('a load while another ad on the MAX unit shows fails alone', () async {
      // MAX shares one rewarded instance per ad unit: while ad A is on
      // screen, a load of ad B on the same unit is refused natively and only
      // B hears about it; A keeps its reward and close.
      final h = ChannelHarness(_rewardedChannel);
      final firedA = <String>[];
      final firedB = <String>[];
      final a = PrebidMaxRewardedAd(
        configId: 'c',
        maxAdUnitId: 'unit',
        listener: _rewardedListener(firedA),
      );
      final b = PrebidMaxRewardedAd(
        configId: 'c',
        maxAdUnitId: 'unit',
        listener: _rewardedListener(firedB),
      );
      await a.loadAd();
      final aId = h.argsOf('load')['adId'] as int;
      await h.emit('onAdLoaded', aId);
      await a.show();
      await h.emit('onAdDisplayed', aId);

      await b.loadAd();
      final bId = h.argsOf('load')['adId'] as int;
      expect(h.argsOf('load')['maxAdUnitId'], 'unit');
      const showing =
          'Another ad for this MAX ad unit is showing; load the next one '
          'after onAdClosed';
      await h.emit('onAdFailed', bId, {'error': showing});
      await h.emit('onUserEarnedReward', aId, {
        'rewardType': 'coins',
        'rewardCount': 1,
      });
      await h.emit('onAdClosed', aId);

      expect(firedB, ['failed:$showing']);
      expect(b.isLoaded, isFalse);
      expect(firedA, ['loaded', 'displayed', 'reward', 'closed']);

      // After the close, B loads normally.
      await b.loadAd();
      await h.emit('onAdLoaded', bId);
      expect(firedB, ['failed:$showing', 'loaded']);
      expect(b.isLoaded, isTrue);
    });

    test('a replaced owner is told so and stops getting events', () async {
      final h = ChannelHarness(_rewardedChannel);
      final firedA = <String>[];
      final a = PrebidMaxRewardedAd(
        configId: 'c',
        maxAdUnitId: 'unit',
        listener: _rewardedListener(firedA),
      );
      await a.loadAd();
      final aId = h.argsOf('load')['adId'] as int;
      await h.emit('onAdFailed', aId, {
        'error': 'Replaced by another ad on the same MAX ad unit',
      });
      expect(firedA, ['failed:Replaced by another ad on the same MAX ad unit']);
      expect(a.isLoaded, isFalse);
    });
  });
}
