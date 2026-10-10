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
  /// Creates a [PrebidReward] with the given [type], [count], and optional [ext] data.
  const PrebidReward({required this.type, required this.count, this.ext});

  /// The reward type identifier (e.g., `"coins"`, `"lives"`, `"points"`).
  ///
  /// `"reward"` when the creative doesn't name one.
  final String type;

  /// The reward amount. `1` when the creative doesn't set one.
  final int count;

  /// Optional extra data from the reward payload.
  final Map<String, dynamic>? ext;
}

/// Listener for SDK initialization events.
///
/// ```dart
/// typedef OnInitializationComplete =
///     void Function(PrebidInitializationStatus status, String? error);
/// ```
typedef OnInitializationComplete =
    void Function(PrebidInitializationStatus status, String? error);

/// Listener for [PrebidBannerAd] lifecycle events.
///
/// All callbacks are optional. Only set the ones you need.
///
/// ```dart
/// PrebidBannerAdListener(
///   onAdLoaded: () => debugPrint('Banner loaded'),
///   onAdDisplayed: () => debugPrint('Banner displayed'),
///   onAdFailed: (error) => debugPrint('Failed: $error'),
///   onAdClicked: () => debugPrint('Clicked'),
///   onAdClosed: () => debugPrint('Closed'),
/// )
/// ```
class PrebidBannerAdListener {
  /// Creates a [PrebidBannerAdListener].
  const PrebidBannerAdListener({
    this.onAdLoaded,
    this.onAdDisplayed,
    this.onAdFailed,
    this.onAdClicked,
    this.onAdClosed,
    this.onAdExpired,
    this.onAdImpression,
  });

  /// Called when the banner ad content has been successfully loaded and is
  /// ready to display.
  final void Function()? onAdLoaded;

  /// Called when the banner ad has been rendered on screen.
  ///
  /// On Android this is a distinct event fired after [onAdLoaded]. iOS reports
  /// load and render as a single event, so on iOS this fires together with
  /// [onAdLoaded].
  final void Function()? onAdDisplayed;

  /// Called when the banner ad fails to load.
  ///
  /// The [error] string contains a human-readable description of the failure.
  final void Function(String error)? onAdFailed;

  /// Called when the user taps on the banner ad.
  final void Function()? onAdClicked;

  /// Called when a fullscreen overlay opened by the banner ad has been closed
  /// by the user (e.g., an in-app browser).
  final void Function()? onAdClosed;

  /// Called when the loaded bid expired (per `bid.exp`) before it was shown.
  ///
  /// Fired by the Prebid rendering banners (`PrebidBannerAd`,
  /// `PrebidGamBannerAd`); mediated banners don't report it.
  final void Function()? onAdExpired;

  /// Called when the ad server records an impression. Fired by mediated
  /// banners (`PrebidAdMobBannerAd`, `PrebidMaxBannerAd`).
  final void Function()? onAdImpression;
}

/// Video playback events of a Prebid-rendered banner showing an outstream
/// video creative (`PrebidBannerAd`, `PrebidGamBannerAd`), mirroring Prebid's
/// `BannerVideoListener` / `BannerViewVideoPlaybackDelegate`.
class PrebidBannerVideoListener {
  /// Creates a [PrebidBannerVideoListener].
  const PrebidBannerVideoListener({
    this.onVideoCompleted,
    this.onVideoPaused,
    this.onVideoResumed,
    this.onVideoMuted,
    this.onVideoUnmuted,
  });

  /// The video played to the end.
  final void Function()? onVideoCompleted;

  /// Playback paused (e.g. the banner scrolled out of view).
  final void Function()? onVideoPaused;

  /// Playback resumed.
  final void Function()? onVideoResumed;

  /// The video was muted.
  final void Function()? onVideoMuted;

  /// The video was unmuted.
  final void Function()? onVideoUnmuted;

  /// Dispatches a native video event name to the matching callback. Returns
  /// `false` for names that aren't video events.
  bool dispatch(String event) {
    final callback = switch (event) {
      'onVideoCompleted' => onVideoCompleted,
      'onVideoPaused' => onVideoPaused,
      'onVideoResumed' => onVideoResumed,
      'onVideoMuted' => onVideoMuted,
      'onVideoUnmuted' => onVideoUnmuted,
      _ => null,
    };
    callback?.call();
    return event.startsWith('onVideo');
  }
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
///   onAdClosed: () => interstitial.destroy(),
///   onAdClicked: () => debugPrint('Clicked'),
/// )
/// ```
class PrebidInterstitialAdListener {
  /// Creates a [PrebidInterstitialAdListener].
  const PrebidInterstitialAdListener({
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdDisplayed,
    this.onAdClosed,
    this.onAdClicked,
    this.onAdExpired,
    this.onAdImpression,
  });

  /// Called when the interstitial ad is loaded and ready to be shown
  /// via [PrebidInterstitialAd.show].
  final void Function()? onAdLoaded;

  /// Called when the interstitial ad fails to load.
  ///
  /// The [error] string contains a description of the failure.
  final void Function(String error)? onAdFailed;

  /// Called when the interstitial ad is presented fullscreen to the user.
  final void Function()? onAdDisplayed;

  /// Called when the user closes the fullscreen interstitial ad.
  ///
  /// This is the appropriate place to call [PrebidInterstitialAd.destroy].
  final void Function()? onAdClosed;

  /// Called when the user taps on the interstitial ad content.
  final void Function()? onAdClicked;

  /// Called when the loaded bid expired (per `bid.exp`) before [show].
  final void Function()? onAdExpired;

  /// Called when the ad server records an impression. Fired by mediated
  /// interstitials (AdMob, MAX).
  final void Function()? onAdImpression;
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
///   onAdClosed: () => rewarded.destroy(),
/// )
/// ```
class PrebidRewardedAdListener {
  /// Creates a [PrebidRewardedAdListener].
  const PrebidRewardedAdListener({
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdDisplayed,
    this.onAdClosed,
    this.onAdClicked,
    this.onUserEarnedReward,
    this.onAdExpired,
    this.onAdImpression,
  });

  /// Called when the rewarded ad is loaded and ready to be shown.
  final void Function()? onAdLoaded;

  /// Called when the rewarded ad fails to load.
  final void Function(String error)? onAdFailed;

  /// Called when the rewarded ad is presented fullscreen.
  final void Function()? onAdDisplayed;

  /// Called when the user closes the rewarded ad.
  final void Function()? onAdClosed;

  /// Called when the user taps on the rewarded ad content.
  final void Function()? onAdClicked;

  /// Called when the user has completed the ad and earned a reward.
  ///
  /// The [reward] contains a [PrebidReward.type] (e.g., `"coins"`),
  /// [PrebidReward.count] (e.g., `100`), and optional [PrebidReward.ext] data.
  final void Function(PrebidReward reward)? onUserEarnedReward;

  /// Called when the loaded bid expired (per `bid.exp`) before it was shown.
  final void Function()? onAdExpired;

  /// Called when the ad server records an impression. Fired by mediated
  /// rewarded ads (AdMob, MAX).
  final void Function()? onAdImpression;
}
