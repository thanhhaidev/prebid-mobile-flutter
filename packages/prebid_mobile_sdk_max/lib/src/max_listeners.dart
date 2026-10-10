import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show
        PrebidBannerAdListener,
        PrebidInterstitialAdListener,
        PrebidRewardedAdListener;

import 'max_banner_ad.dart';
import 'max_interstitial_ad.dart';
import 'max_rewarded_ad.dart';

/// The revenue AppLovin MAX reports for an ad impression
/// (`MaxAdRevenueListener.onAdRevenuePaid` / `MAAdRevenueDelegate
/// didPayRevenueForAd:`), passed to the `onAdRevenuePaid` callbacks of the
/// MAX listeners.
class PrebidMaxAdRevenue {
  /// Creates a [PrebidMaxAdRevenue].
  const PrebidMaxAdRevenue({
    required this.revenue,
    this.revenuePrecision = '',
    this.networkName = '',
    this.placement,
  });

  /// The impression's revenue in USD; `0` when MAX has no value (e.g. in test
  /// mode).
  final double revenue;

  /// Precision of [revenue]: `exact`, `estimated`, `publisher_defined`,
  /// `undefined`, or empty when not valid.
  final String revenuePrecision;

  /// The network that served the ad (e.g. `Prebid` when the Prebid adapter
  /// won).
  final String networkName;

  /// The placement name set for the ad in MAX, if any.
  final String? placement;

  @override
  String toString() =>
      'PrebidMaxAdRevenue(revenue: $revenue, precision: $revenuePrecision, '
      'network: $networkName, placement: $placement)';
}

/// Builds the [PrebidMaxAdRevenue] from an `onAdRevenuePaid` payload. Not
/// exported.
PrebidMaxAdRevenue maxAdRevenueFrom(Map? args) => PrebidMaxAdRevenue(
  revenue: (args?['revenue'] as num?)?.toDouble() ?? 0,
  revenuePrecision: args?['revenuePrecision'] as String? ?? '',
  networkName: args?['networkName'] as String? ?? '',
  placement: args?['placement'] as String?,
);

/// A [PrebidBannerAdListener] with the extra events of a [PrebidMaxBannerAd]
/// (`MaxAdViewAdListener` / `MAAdViewAdDelegate` and the revenue callback).
/// Pass it as the banner's `listener`.
class PrebidMaxBannerAdListener extends PrebidBannerAdListener {
  /// Creates a [PrebidMaxBannerAdListener].
  const PrebidMaxBannerAdListener({
    super.onAdLoaded,
    super.onAdDisplayed,
    super.onAdFailed,
    super.onAdClicked,
    super.onAdClosed,
    super.onAdExpired,
    super.onAdImpression,
    this.onAdExpanded,
    this.onAdCollapsed,
    this.onAdDisplayFailed,
    this.onAdRevenuePaid,
  });

  /// The banner expanded to fullscreen content (e.g. an MRAID expand).
  final void Function()? onAdExpanded;

  /// The expanded banner collapsed back to its slot.
  final void Function()? onAdCollapsed;

  /// MAX loaded the banner but failed to display it. Also reported through
  /// [onAdFailed].
  final void Function(String error)? onAdDisplayFailed;

  /// MAX paid revenue for an impression (it also fires [onAdImpression]).
  final void Function(PrebidMaxAdRevenue revenue)? onAdRevenuePaid;
}

/// A [PrebidInterstitialAdListener] with the revenue callback of a
/// [PrebidMaxInterstitialAd]. Pass it as the interstitial's `listener`.
class PrebidMaxInterstitialAdListener extends PrebidInterstitialAdListener {
  /// Creates a [PrebidMaxInterstitialAdListener].
  const PrebidMaxInterstitialAdListener({
    super.onAdLoaded,
    super.onAdFailed,
    super.onAdDisplayed,
    super.onAdClosed,
    super.onAdClicked,
    super.onAdExpired,
    super.onAdImpression,
    this.onAdRevenuePaid,
  });

  /// MAX paid revenue for an impression (it also fires [onAdImpression]).
  final void Function(PrebidMaxAdRevenue revenue)? onAdRevenuePaid;
}

/// A [PrebidRewardedAdListener] with the revenue callback of a
/// [PrebidMaxRewardedAd]. Pass it as the rewarded ad's `listener`.
class PrebidMaxRewardedAdListener extends PrebidRewardedAdListener {
  /// Creates a [PrebidMaxRewardedAdListener].
  const PrebidMaxRewardedAdListener({
    super.onAdLoaded,
    super.onAdFailed,
    super.onAdDisplayed,
    super.onAdClosed,
    super.onAdClicked,
    super.onUserEarnedReward,
    super.onAdExpired,
    super.onAdImpression,
    this.onAdRevenuePaid,
  });

  /// MAX paid revenue for an impression (it also fires [onAdImpression]).
  final void Function(PrebidMaxAdRevenue revenue)? onAdRevenuePaid;
}
