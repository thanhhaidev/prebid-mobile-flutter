import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

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
      expect(ad.isLoaded, isTrue);

      await ad.show();
      expect(h.calls.last.method, 'show');
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
      await h.emit('onUserEarnedReward', adId, {'type': 'coins', 'count': 3});
      expect(impressions, 1);
      expect(reward?.type, 'coins');
      expect(reward?.count, 3);
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
