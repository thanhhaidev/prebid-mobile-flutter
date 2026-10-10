import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

void main() {
  group('PrebidAdFormat', () {
    test('has banner and video', () {
      expect(PrebidAdFormat.values.length, 2);
      expect(PrebidAdFormat.values, contains(PrebidAdFormat.banner));
      expect(PrebidAdFormat.values, contains(PrebidAdFormat.video));
    });
  });

  group('PrebidLogLevel', () {
    test('has all log levels', () {
      expect(PrebidLogLevel.values.length, 6);
      expect(
        PrebidLogLevel.values,
        containsAll([
          PrebidLogLevel.debug,
          PrebidLogLevel.verbose,
          PrebidLogLevel.info,
          PrebidLogLevel.warn,
          PrebidLogLevel.error,
          PrebidLogLevel.severe,
        ]),
      );
    });
  });

  group('PrebidInitializationStatus', () {
    test('has all statuses', () {
      expect(PrebidInitializationStatus.values.length, 3);
      expect(
        PrebidInitializationStatus.values,
        containsAll([
          PrebidInitializationStatus.succeeded,
          PrebidInitializationStatus.failed,
          PrebidInitializationStatus.serverStatusWarning,
        ]),
      );
    });
  });

  group('PrebidReward', () {
    test('creates with all fields', () {
      const reward = PrebidReward(
        type: 'coins',
        count: 100,
        ext: {'bonus': 'true'},
      );

      expect(reward.type, 'coins');
      expect(reward.count, 100);
      expect(reward.ext, {'bonus': 'true'});
    });

    test('creates with minimal fields', () {
      const reward = PrebidReward(type: 'reward', count: 1);

      expect(reward.type, 'reward');
      expect(reward.count, 1);
      expect(reward.ext, isNull);
    });
  });

  group('PrebidBannerAdListener', () {
    test('accepts callbacks', () {
      var loaded = false;
      var failed = false;
      var clicked = false;
      var closed = false;

      final listener = PrebidBannerAdListener(
        onAdLoaded: () => loaded = true,
        onAdFailed: (error) => failed = true,
        onAdClicked: () => clicked = true,
        onAdClosed: () => closed = true,
      );

      listener.onAdLoaded?.call();
      listener.onAdFailed?.call('error');
      listener.onAdClicked?.call();
      listener.onAdClosed?.call();

      expect(loaded, true);
      expect(failed, true);
      expect(clicked, true);
      expect(closed, true);
    });

    test('callbacks are optional', () {
      const listener = PrebidBannerAdListener();

      expect(listener.onAdLoaded, isNull);
      expect(listener.onAdFailed, isNull);
      expect(listener.onAdClicked, isNull);
      expect(listener.onAdClosed, isNull);
    });
  });

  group('PrebidInterstitialAdListener', () {
    test('accepts all callbacks', () {
      var loadedCalled = false;
      var failedCalled = false;
      var displayedCalled = false;
      var closedCalled = false;
      var clickedCalled = false;

      final listener = PrebidInterstitialAdListener(
        onAdLoaded: () => loadedCalled = true,
        onAdFailed: (error) => failedCalled = true,
        onAdDisplayed: () => displayedCalled = true,
        onAdClosed: () => closedCalled = true,
        onAdClicked: () => clickedCalled = true,
      );

      listener.onAdLoaded?.call();
      listener.onAdFailed?.call('error');
      listener.onAdDisplayed?.call();
      listener.onAdClosed?.call();
      listener.onAdClicked?.call();

      expect(loadedCalled, true);
      expect(failedCalled, true);
      expect(displayedCalled, true);
      expect(closedCalled, true);
      expect(clickedCalled, true);
    });
  });

  group('PrebidRewardedAdListener', () {
    test('handles reward callback', () {
      PrebidReward? earnedReward;

      final listener = PrebidRewardedAdListener(
        onUserEarnedReward: (reward) => earnedReward = reward,
      );

      const testReward = PrebidReward(type: 'gold', count: 50);
      listener.onUserEarnedReward?.call(testReward);

      expect(earnedReward, isNotNull);
      expect(earnedReward!.type, 'gold');
      expect(earnedReward!.count, 50);
    });
  });
}
