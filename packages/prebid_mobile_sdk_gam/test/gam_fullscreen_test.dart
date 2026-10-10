import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';

import 'channel_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrebidGamInterstitialAd', () {
    test('load sends formats, targeting and controls; routes events', () async {
      final h = ChannelHarness('prebid_mobile_sdk_gam/interstitial');
      final fired = <String>[];
      final ad = PrebidGamInterstitialAd(
        configId: 'config-i',
        gamAdUnitId: '/1/inter',
        adFormats: {PrebidAdFormat.video},
        customTargeting: const {'section': 'news'},
        controls: const PrebidFullscreenControls(
          closeButtonPosition: PrebidButtonPosition.topLeft,
          skipDelay: 5,
          supportSKOverlay: true,
        ),
        videoParameters: const VideoParameters(
          mimes: ['video/mp4'],
          plcmt: VideoPlcmt.interstitial,
          startDelay: VideoStartDelay.preRoll,
          linearity: VideoLinearity.linear,
          skippable: true,
          battr: [VideoCreativeAttribute.pop],
          minBitrate: 300,
          maxBitrate: 1500,
          maxDuration: 30,
        ),
        listener: PrebidInterstitialAdListener(
          onAdLoaded: () => fired.add('loaded'),
          onAdFailed: (e) => fired.add('failed:$e'),
          onAdExpired: () => fired.add('expired'),
        ),
      );
      await ad.loadAd();

      final args = h.argsOf('load');
      expect(args['configId'], 'config-i');
      expect(args['gamAdUnitId'], '/1/inter');
      expect(args['adFormats'], ['video']);
      expect(args['customTargeting'], {'section': 'news'});
      expect(args['controls'], {
        'closeButtonPosition': 'topLeft',
        'skipDelay': 5,
        'supportSKOverlay': true,
      });
      expect(args['videoParameters'], {
        'mimes': ['video/mp4'],
        'maxDuration': 30,
        'plcmt': 3,
        'startDelay': 0,
        'linearity': 1,
        'skippable': true,
        'battr': [8],
        'minBitrate': 300,
        'maxBitrate': 1500,
      });

      final adId = args['adId'] as int;
      await h.emit('onAdLoaded', adId);
      await h.emit('onAdFailed', adId, {'error': 'boom'});
      await h.emit('onAdExpired', adId);
      await h.emit('onAdLoaded', adId + 1); // another ad: ignored
      expect(fired, ['loaded', 'failed:boom', 'expired']);
      expect(ad.isLoaded, isFalse); // failed / expired

      await h.emit('onAdLoaded', adId);
      expect(ad.isLoaded, isTrue);
      await ad.show();
      expect(h.calls.last.method, 'show');
      expect(ad.isLoaded, isFalse);

      await ad.destroy();
      await h.emit('onAdLoaded', adId); // unregistered: ignored
      expect(fired, hasLength(4));
    });
  });

  group('PrebidGamRewardedAd', () {
    test('forwards controls and decodes the reward ext', () async {
      final h = ChannelHarness('prebid_mobile_sdk_gam/rewarded');
      PrebidReward? reward;
      final ad = PrebidGamRewardedAd(
        configId: 'config-r',
        gamAdUnitId: '/1/rewarded',
        controls: const PrebidFullscreenControls(
          isMuted: true,
          supportSKOverlay: false,
        ),
        videoParameters: const VideoParameters(
          mimes: ['video/mp4'],
          maxDuration: 60,
        ),
        listener: PrebidRewardedAdListener(
          onUserEarnedReward: (r) => reward = r,
        ),
      );
      await ad.loadAd();
      final args = h.argsOf('load');
      expect(args['controls'], {'isMuted': true, 'supportSKOverlay': false});
      expect(args['videoParameters'], {
        'mimes': ['video/mp4'],
        'maxDuration': 60,
      });
      expect(args.containsKey('customTargeting'), isFalse);

      await h.emit('onUserEarnedReward', args['adId'] as int, {
        'rewardType': 'coins',
        'rewardCount': 10,
        'rewardExt': '{"bonus":true}',
      });
      expect(reward?.type, 'coins');
      expect(reward?.count, 10);
      expect(reward?.ext, {'bonus': true});
    });

    test('defaults a bare reward and resets isLoaded on close', () async {
      final h = ChannelHarness('prebid_mobile_sdk_gam/rewarded');
      final rewards = <PrebidReward>[];
      final ad = PrebidGamRewardedAd(
        configId: 'config-r',
        gamAdUnitId: '/1/rewarded',
        listener: PrebidRewardedAdListener(onUserEarnedReward: rewards.add),
      );
      await ad.loadAd();
      expect(h.argsOf('load').containsKey('videoParameters'), isFalse);
      final adId = h.argsOf('load')['adId'] as int;

      await h.emit('onAdLoaded', adId);
      expect(ad.isLoaded, isTrue);
      await h.emit('onUserEarnedReward', adId);
      await h.emit('onAdClosed', adId);
      expect(ad.isLoaded, isFalse);
      expect(rewards.single.type, 'reward');
      expect(rewards.single.count, 1);
      expect(rewards.single.ext, isNull);
    });
  });
}
