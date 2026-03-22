import 'ad_enums.dart';

/// Reward data returned by rewarded ads.
class PrebidReward {
  final String? type;
  final int? count;
  final Map<String, dynamic>? ext;

  const PrebidReward({this.type, this.count, this.ext});

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
typedef OnInitializationComplete = void Function(InitializationStatus status, String? error);

/// Listener for banner ad events.
class PrebidBannerAdListener {
  final void Function()? onAdLoaded;
  final void Function(String error)? onAdFailed;
  final void Function()? onAdClicked;
  final void Function()? onAdClosed;

  const PrebidBannerAdListener({
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdClicked,
    this.onAdClosed,
  });
}

/// Listener for interstitial ad events.
class PrebidInterstitialAdListener {
  final void Function()? onAdLoaded;
  final void Function(String error)? onAdFailed;
  final void Function()? onAdDisplayed;
  final void Function()? onAdDismissed;
  final void Function()? onAdClicked;

  const PrebidInterstitialAdListener({
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdDisplayed,
    this.onAdDismissed,
    this.onAdClicked,
  });
}

/// Listener for rewarded ad events.
class PrebidRewardedAdListener {
  final void Function()? onAdLoaded;
  final void Function(String error)? onAdFailed;
  final void Function()? onAdDisplayed;
  final void Function()? onAdDismissed;
  final void Function()? onAdClicked;
  final void Function(PrebidReward reward)? onUserEarnedReward;

  const PrebidRewardedAdListener({
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdDisplayed,
    this.onAdDismissed,
    this.onAdClicked,
    this.onUserEarnedReward,
  });
}
