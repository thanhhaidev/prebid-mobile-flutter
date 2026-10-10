import 'admob_banner_ad.dart';
import 'admob_interstitial_ad.dart';
import 'admob_rewarded_ad.dart';

/// Package-wide settings of the AdMob companion.
///
/// Holds only a testing hook today; it is not needed to show ads.
abstract final class PrebidAdMob {
  /// **Testing only — leave at `0` in production apps.**
  ///
  /// Probability (`0..1`) that the Prebid bid is thrown away after the
  /// auction and before AdMob loads, so the Prebid AdMob adapter finds no bid
  /// and AdMob falls back to the next source in its waterfall. It reproduces
  /// Prebid's internal test app "Random" cases (which use `0.5`) to exercise
  /// the adapter's no-bid path.
  ///
  /// Read at each [PrebidAdMobBannerAd] creation and each
  /// [PrebidAdMobInterstitialAd] / [PrebidAdMobRewardedAd] `loadAd()`; banners
  /// roll again on every auto-refresh. Native ads ignore it. Natively:
  ///
  /// - **Android** pops the bid from Prebid's `BidResponseCache` (exactly as
  ///   the test app does).
  /// - **iOS** clears the Prebid custom-event extras on the AdMob request
  ///   (Prebid iOS has no bid cache: the bid travels in those extras), while
  ///   the `hb_*` keywords stay.
  ///
  /// Values outside `0..1` are clamped.
  static double debugDropBidProbability = 0;
}

/// Channel argument for [PrebidAdMob.debugDropBidProbability]: absent unless
/// it is above `0`. Not exported.
Map<String, Object> debugDropBidArgs() {
  final p = PrebidAdMob.debugDropBidProbability;
  if (p.isNaN || p <= 0) return const {};
  return {'debugDropBidProbability': p > 1 ? 1.0 : p};
}
