import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

void main() {
  group('PrebidException', () {
    test('creates with required fields', () {
      const exception = PrebidException(
        code: PrebidErrorCode.adLoadFailed,
        message: 'Ad failed to load',
      );

      expect(exception.code, PrebidErrorCode.adLoadFailed);
      expect(exception.message, 'Ad failed to load');
      expect(exception.details, isNull);
    });

    test('creates with optional details', () {
      const exception = PrebidException(
        code: PrebidErrorCode.networkError,
        message: 'Network error',
        details: 'Connection timed out',
      );

      expect(exception.details, 'Connection timed out');
    });

    test('toString without details', () {
      const exception = PrebidException(
        code: PrebidErrorCode.adLoadFailed,
        message: 'Ad failed',
      );

      expect(
        exception.toString(),
        'PrebidException(PrebidErrorCode.adLoadFailed): Ad failed',
      );
    });

    test('toString with details', () {
      const exception = PrebidException(
        code: PrebidErrorCode.serverError,
        message: 'Server error',
        details: '500 Internal',
      );

      expect(
        exception.toString(),
        'PrebidException(PrebidErrorCode.serverError): Server error (500 Internal)',
      );
    });
  });

  group('PrebidErrorCode', () {
    test('contains all expected values', () {
      expect(
        PrebidErrorCode.values,
        containsAll([
          PrebidErrorCode.initializationFailed,
          PrebidErrorCode.invalidArguments,
          PrebidErrorCode.adLoadFailed,
          PrebidErrorCode.adNotFound,
          PrebidErrorCode.adDisplayFailed,
          PrebidErrorCode.networkError,
          PrebidErrorCode.serverError,
          PrebidErrorCode.timeout,
          PrebidErrorCode.unknown,
        ]),
      );
    });
  });

  group('AdFormat', () {
    test('has banner and video', () {
      expect(AdFormat.values.length, 2);
      expect(AdFormat.values, contains(AdFormat.banner));
      expect(AdFormat.values, contains(AdFormat.video));
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

  group('InitializationStatus', () {
    test('has all statuses', () {
      expect(InitializationStatus.values.length, 3);
      expect(
        InitializationStatus.values,
        containsAll([
          InitializationStatus.succeeded,
          InitializationStatus.failed,
          InitializationStatus.serverStatusWarning,
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
      var dismissedCalled = false;
      var clickedCalled = false;

      final listener = PrebidInterstitialAdListener(
        onAdLoaded: () => loadedCalled = true,
        onAdFailed: (error) => failedCalled = true,
        onAdDisplayed: () => displayedCalled = true,
        onAdDismissed: () => dismissedCalled = true,
        onAdClicked: () => clickedCalled = true,
      );

      listener.onAdLoaded?.call();
      listener.onAdFailed?.call('error');
      listener.onAdDisplayed?.call();
      listener.onAdDismissed?.call();
      listener.onAdClicked?.call();

      expect(loadedCalled, true);
      expect(failedCalled, true);
      expect(displayedCalled, true);
      expect(dismissedCalled, true);
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
