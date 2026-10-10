import 'max_banner_ad.dart';
import 'max_interstitial_ad.dart';
import 'max_rewarded_ad.dart';

/// Package-wide settings of the AppLovin MAX companion.
///
/// Holds only a testing hook today; it is not needed to show ads.
abstract final class PrebidMax {
  /// **Testing only — leave at `0` in production apps.**
  ///
  /// Probability (`0..1`) that the Prebid bid is withheld from MAX after the
  /// auction, so the Prebid MAX adapter finds no bid and MAX falls back to
  /// the next network in its waterfall. It reproduces Prebid's internal test
  /// app "Random" cases (which use `0.5`) to exercise the adapter's no-bid
  /// path.
  ///
  /// Read at each [PrebidMaxBannerAd] creation and each
  /// [PrebidMaxInterstitialAd] / [PrebidMaxRewardedAd] `loadAd()`; banners
  /// roll again on every auto-refresh. Native ads ignore it. Natively:
  ///
  /// - **Android** sets the MAX local extra
  ///   `PrebidMaxMediationAdapter.EXTRA_RESPONSE_ID` to `""` (exactly as the
  ///   test app does).
  /// - **iOS** clears the bid local extra (`PBMMediationAdUnitBidKey`) on the
  ///   MAX ad object — Prebid iOS passes the bid itself, not a response id.
  ///
  /// Values outside `0..1` are clamped.
  static double debugDropBidProbability = 0;
}

/// Channel argument for [PrebidMax.debugDropBidProbability]: absent unless it
/// is above `0`. Not exported.
Map<String, Object> debugDropBidArgs() {
  final p = PrebidMax.debugDropBidProbability;
  if (p.isNaN || p <= 0) return const {};
  return {'debugDropBidProbability': p > 1 ? 1.0 : p};
}
