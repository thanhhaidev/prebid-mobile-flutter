import 'ad_enums.dart';

/// Reward data returned by rewarded ads when a user completes the ad experience.
///
/// Passed to [PrebidRewardedAdListener.onUserEarnedReward].
///
/// ```dart
/// onUserEarnedReward: (reward) {
///   debugPrint('Earned ${reward.count}x ${reward.type}');
/// },
/// ```
class PrebidReward {
  /// The reward type identifier (e.g., `"coins"`, `"lives"`, `"points"`).
  final String? type;

  /// The reward amount.
  final int? count;

  /// Optional extra data from the reward payload.
  final Map<String, dynamic>? ext;

  /// Creates a [PrebidReward] with the given [type], [count], and optional [ext] data.
  const PrebidReward({this.type, this.count, this.ext});

  /// Creates a [PrebidReward] from a deserialized map.
  factory PrebidReward.fromMap(Map<String, dynamic> map) {
    return PrebidReward(
      type: map['type'] as String?,
      count: map['count'] as int?,
      ext: map['ext'] != null
          ? Map<String, dynamic>.from(map['ext'] as Map)
          : null,
    );
  }
}

/// Listener for SDK initialization events.
///
/// ```dart
/// typedef OnInitializationComplete =
///     void Function(InitializationStatus status, String? error);
/// ```
typedef OnInitializationComplete =
    void Function(InitializationStatus status, String? error);

/// Listener for [PrebidBannerAd] lifecycle events.
///
/// All callbacks are optional. Only set the ones you need.
///
/// ```dart
/// PrebidBannerAdListener(
///   onAdLoaded: () => debugPrint('Banner loaded'),
///   onAdFailed: (error) => debugPrint('Failed: $error'),
///   onAdClicked: () => debugPrint('Clicked'),
///   onAdClosed: () => debugPrint('Closed'),
/// )
/// ```
class PrebidBannerAdListener {
  /// Called when the banner ad content has been successfully loaded and is
  /// ready to display.
  final void Function()? onAdLoaded;

  /// Called when the banner ad fails to load.
  ///
  /// The [error] string contains a human-readable description of the failure.
  final void Function(String error)? onAdFailed;

  /// Called when the user taps on the banner ad.
  final void Function()? onAdClicked;

  /// Called when a fullscreen overlay opened by the banner ad has been closed
  /// by the user (e.g., an in-app browser).
  final void Function()? onAdClosed;

  /// Creates a [PrebidBannerAdListener].
  const PrebidBannerAdListener({
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdClicked,
    this.onAdClosed,
  });
}

/// Listener for [PrebidInterstitialAd] lifecycle events.
///
/// All callbacks are optional. Only set the ones you need.
///
/// ```dart
/// PrebidInterstitialAdListener(
///   onAdLoaded: () => interstitial.show(),
///   onAdFailed: (error) => debugPrint('Failed: $error'),
///   onAdDisplayed: () => debugPrint('Displayed'),
///   onAdDismissed: () => interstitial.destroy(),
///   onAdClicked: () => debugPrint('Clicked'),
/// )
/// ```
class PrebidInterstitialAdListener {
  /// Called when the interstitial ad is loaded and ready to be shown
  /// via [PrebidInterstitialAd.show].
  final void Function()? onAdLoaded;

  /// Called when the interstitial ad fails to load.
  ///
  /// The [error] string contains a description of the failure.
  final void Function(String error)? onAdFailed;

  /// Called when the interstitial ad is presented fullscreen to the user.
  final void Function()? onAdDisplayed;

  /// Called when the user dismisses the fullscreen interstitial ad.
  ///
  /// This is the appropriate place to call [PrebidInterstitialAd.destroy].
  final void Function()? onAdDismissed;

  /// Called when the user taps on the interstitial ad content.
  final void Function()? onAdClicked;

  /// Creates a [PrebidInterstitialAdListener].
  const PrebidInterstitialAdListener({
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdDisplayed,
    this.onAdDismissed,
    this.onAdClicked,
  });
}

/// Listener for [PrebidRewardedAd] lifecycle events.
///
/// All callbacks are optional. The [onUserEarnedReward] callback provides
/// a [PrebidReward] instance containing the reward type, count, and
/// optional extra data.
///
/// ```dart
/// PrebidRewardedAdListener(
///   onAdLoaded: () => rewarded.show(),
///   onUserEarnedReward: (reward) {
///     debugPrint('Reward: ${reward.count}x ${reward.type}');
///   },
///   onAdDismissed: () => rewarded.destroy(),
/// )
/// ```
class PrebidRewardedAdListener {
  /// Called when the rewarded ad is loaded and ready to be shown.
  final void Function()? onAdLoaded;

  /// Called when the rewarded ad fails to load.
  final void Function(String error)? onAdFailed;

  /// Called when the rewarded ad is presented fullscreen.
  final void Function()? onAdDisplayed;

  /// Called when the user dismisses the rewarded ad.
  final void Function()? onAdDismissed;

  /// Called when the user taps on the rewarded ad content.
  final void Function()? onAdClicked;

  /// Called when the user has completed the ad and earned a reward.
  ///
  /// The [reward] contains a [PrebidReward.type] (e.g., `"coins"`),
  /// [PrebidReward.count] (e.g., `100`), and optional [PrebidReward.ext] data.
  final void Function(PrebidReward reward)? onUserEarnedReward;

  /// Creates a [PrebidRewardedAdListener].
  const PrebidRewardedAdListener({
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdDisplayed,
    this.onAdDismissed,
    this.onAdClicked,
    this.onUserEarnedReward,
  });
}
