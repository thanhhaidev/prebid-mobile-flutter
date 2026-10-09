import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrebidGamInterstitialAd', () {
    test('load sends formats, targeting and controls; routes events', () async {
      final h = ChannelHarness('prebid_mobile_sdk_gam/interstitial');
      final fired = <String>[];
      final ad = PrebidGamInterstitialAd(
        configId: 'config-i',
        gamAdUnitId: '/1/inter',
        adFormats: {AdFormat.video},
        customTargeting: const {'section': 'news'},
        controls: const PrebidFullscreenControls(
          closeButtonPosition: PrebidButtonPosition.topLeft,
          skipDelay: 5,
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
      });

      final adId = args['adId'] as int;
      await h.emit('onAdLoaded', adId);
      await h.emit('onAdFailed', adId, {'error': 'boom'});
      await h.emit('onAdExpired', adId);
      await h.emit('onAdLoaded', adId + 1); // another ad: ignored
      expect(fired, ['loaded', 'failed:boom', 'expired']);
      expect(ad.isLoaded, isTrue);

      await ad.destroy();
      await h.emit('onAdLoaded', adId); // unregistered: ignored
      expect(fired, hasLength(3));
    });
  });

  group('PrebidGamRewardedAd', () {
    test('forwards controls and decodes the reward ext', () async {
      final h = ChannelHarness('prebid_mobile_sdk_gam/rewarded');
      PrebidReward? reward;
      final ad = PrebidGamRewardedAd(
        configId: 'config-r',
        gamAdUnitId: '/1/rewarded',
        controls: const PrebidFullscreenControls(isMuted: true),
        listener: PrebidRewardedAdListener(
          onUserEarnedReward: (r) => reward = r,
        ),
      );
      await ad.loadAd();
      final args = h.argsOf('load');
      expect(args['controls'], {'isMuted': true});
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
  });
}

/// Records method calls sent to [channel] and lets a test push native events
/// back over it, as the plugin's Kotlin / Swift side does.
class ChannelHarness {
  ChannelHarness(this.channel) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), (call) async {
          calls.add(call);
          return null;
        });
  }

  final String channel;
  final List<MethodCall> calls = [];

  Map<Object?, Object?> argsOf(String method) =>
      calls.lastWhere((c) => c.method == method).arguments as Map;

  /// Delivers a native → Dart event for [adId].
  Future<void> emit(String event, int adId, [Map<String, Object?>? extra]) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall(event, {'adId': adId, ...?extra}),
            ),
            (_) {},
          );
}
