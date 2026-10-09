import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import 'channel_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrebidMaxInterstitialAd', () {
    test('load sends video flag and controls; routes events', () async {
      final h = ChannelHarness('prebid_mobile_sdk_max/interstitial');
      final fired = <String>[];
      final ad = PrebidMaxInterstitialAd(
        configId: 'config-i',
        maxAdUnitId: 'unit-i',
        isVideo: true,
        controls: const PrebidFullscreenControls(
          minSizePercentage: Size(50, 70),
        ),
        listener: PrebidInterstitialAdListener(
          onAdLoaded: () => fired.add('loaded'),
          onAdDisplayed: () => fired.add('displayed'),
          onAdImpression: () => fired.add('impression'),
          onAdClicked: () => fired.add('clicked'),
          onAdClosed: () => fired.add('closed'),
        ),
      );
      await ad.loadAd();

      final args = h.argsOf('load');
      expect(args['configId'], 'config-i');
      expect(args['maxAdUnitId'], 'unit-i');
      expect(args['isVideo'], isTrue);
      expect(args['controls'], {
        'minWidthPercentage': 50,
        'minHeightPercentage': 70,
      });

      final adId = args['adId'] as int;
      for (final e in [
        'onAdLoaded',
        'onAdDisplayed',
        'onAdImpression',
        'onAdClicked',
        'onAdClosed',
      ]) {
        await h.emit(e, adId);
      }
      expect(fired, ['loaded', 'displayed', 'impression', 'clicked', 'closed']);
      expect(ad.isLoaded, isFalse); // closed

      await h.emit('onAdLoaded', adId);
      await ad.show();
      expect(h.calls.last.method, 'show');
      expect(ad.isLoaded, isFalse);
      await h.emit('onAdLoaded', adId);
      await h.emit('onAdFailed', adId, {'error': 'x'});
      expect(ad.isLoaded, isFalse);
      await ad.destroy();
      expect(h.calls.last.method, 'destroy');
    });
  });

  group('PrebidMaxRewardedAd', () {
    test('forwards controls and maps the reward', () async {
      final h = ChannelHarness('prebid_mobile_sdk_max/rewarded');
      PrebidReward? reward;
      var impressions = 0;
      final ad = PrebidMaxRewardedAd(
        configId: 'config-r',
        maxAdUnitId: 'unit-r',
        controls: const PrebidFullscreenControls(isSoundButtonVisible: true),
        listener: PrebidRewardedAdListener(
          onUserEarnedReward: (r) => reward = r,
          onAdImpression: () => impressions++,
        ),
      );
      await ad.loadAd();
      final args = h.argsOf('load');
      expect(args['controls'], {'isSoundButtonVisible': true});

      final adId = args['adId'] as int;
      await h.emit('onAdImpression', adId);
      await h.emit('onUserEarnedReward', adId, {
        'rewardType': 'coins',
        'rewardCount': 3,
      });
      expect(impressions, 1);
      expect(reward?.type, 'coins');
      expect(reward?.count, 3);
      expect(reward?.ext, isNull);
    });

    test('reward parsing matches the GAM package (defaults + ext)', () async {
      final h = ChannelHarness('prebid_mobile_sdk_max/rewarded');
      final rewards = <PrebidReward>[];
      final ad = PrebidMaxRewardedAd(
        configId: 'config-r',
        maxAdUnitId: 'unit-r',
        listener: PrebidRewardedAdListener(onUserEarnedReward: rewards.add),
      );
      await ad.loadAd();
      final adId = h.argsOf('load')['adId'] as int;

      await h.emit('onUserEarnedReward', adId);
      await h.emit('onUserEarnedReward', adId, {
        'rewardType': 'gems',
        'rewardCount': 2,
        'rewardExt': '{"tier":1}',
      });
      expect(rewards.map((r) => [r.type, r.count, r.ext]), [
        ['reward', 1, null],
        [
          'gems',
          2,
          {'tier': 1},
        ],
      ]);
    });

    test('isLoaded resets on show, close and failure', () async {
      final h = ChannelHarness('prebid_mobile_sdk_max/rewarded');
      final ad = PrebidMaxRewardedAd(configId: 'c', maxAdUnitId: 'u');
      await ad.loadAd();
      final adId = h.argsOf('load')['adId'] as int;

      await h.emit('onAdLoaded', adId);
      expect(ad.isLoaded, isTrue);
      await ad.show();
      expect(h.calls.last.method, 'show');
      expect(ad.isLoaded, isFalse);

      await h.emit('onAdLoaded', adId);
      await h.emit('onAdClosed', adId);
      expect(ad.isLoaded, isFalse);

      await h.emit('onAdLoaded', adId);
      await h.emit('onAdFailed', adId, {'error': 'not ready'});
      expect(ad.isLoaded, isFalse);

      await h.emit('onAdLoaded', adId);
      await ad.destroy();
      expect(ad.isLoaded, isFalse);
    });
  });
}
