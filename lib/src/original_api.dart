import 'dart:ui' show Size;

import 'multiformat_ad.dart';
import 'video_parameters.dart';

/// Result of an **Original API** bid request.
///
/// In the Original API integration the Prebid SDK only runs the auction and
/// returns [targetingKeywords]; your primary ad server SDK (e.g. Google Ad
/// Manager via `google_mobile_ads`) renders the ad. Pass [targetingKeywords]
/// to your ad request as custom targeting.
class PrebidBidResponse {
  /// The raw Prebid result code (e.g. `prebidDemandFetchSuccess`).
  final String resultCode;

  /// Bid-winning targeting keywords to hand to your ad server, or `null`/empty
  /// when there was no bid.
  final Map<String, String>? targetingKeywords;

  /// Whether the auction returned a winning bid.
  bool get isSuccess => resultCode == 'prebidDemandFetchSuccess';

  const PrebidBidResponse({required this.resultCode, this.targetingKeywords});
}

/// A banner ad unit for the **Original API** integration: Prebid runs the
/// auction and returns targeting keywords for your ad server to render (it does
/// **not** render the ad itself — use [PrebidBannerAd] for Prebid rendering).
///
/// ```dart
/// final adUnit = PrebidBannerAdUnit(
///   configId: 'your-config-id',
///   sizes: const [Size(300, 250)],
/// );
/// final response = await adUnit.fetchDemand();
/// // Hand response.targetingKeywords to google_mobile_ads:
/// //   AdManagerAdRequest(customTargeting: response.targetingKeywords ?? {})
/// ```
class PrebidBannerAdUnit {
  /// The Prebid Server stored impression config ID.
  final String configId;

  /// Banner sizes to request (e.g. `[Size(300, 250)]`).
  final List<Size> sizes;

  final PrebidMultiformatAd _delegate;

  /// Creates a [PrebidBannerAdUnit].
  PrebidBannerAdUnit({required this.configId, required this.sizes})
    : _delegate = PrebidMultiformatAd(configId: configId, bannerSizes: sizes);

  /// Runs the Prebid auction and returns targeting keywords for your ad server.
  Future<PrebidBidResponse> fetchDemand() async {
    final result = await _delegate.fetchDemand();
    return PrebidBidResponse(
      resultCode: result.resultCode,
      targetingKeywords: result.targetingKeywords,
    );
  }

  /// Releases native resources held by this ad unit.
  Future<void> destroy() => _delegate.destroy();
}

/// An interstitial ad unit for the **Original API** integration: Prebid runs
/// the auction and returns targeting keywords for your ad server to render the
/// interstitial (use [PrebidInterstitialAd] for Prebid rendering instead).
///
/// Provide [sizes] for a display interstitial and/or [videoParameters] for a
/// video interstitial — at least one is required to form a valid request.
///
/// ```dart
/// final adUnit = PrebidInterstitialAdUnit(
///   configId: 'your-config-id',
///   sizes: const [Size(320, 480)],
/// );
/// final response = await adUnit.fetchDemand();
/// // AdManagerInterstitialAd.load(
/// //   adRequest: AdManagerAdRequest(customTargeting: response.targetingKeywords ?? {}),
/// // );
/// ```
class PrebidInterstitialAdUnit {
  /// The Prebid Server stored impression config ID.
  final String configId;

  /// Display interstitial sizes (optional if [videoParameters] is set).
  final List<Size>? sizes;

  /// Video parameters for a video interstitial (optional if [sizes] is set).
  final VideoParameters? videoParameters;

  final PrebidMultiformatAd _delegate;

  /// Creates a [PrebidInterstitialAdUnit].
  PrebidInterstitialAdUnit({
    required this.configId,
    this.sizes,
    this.videoParameters,
  }) : _delegate = PrebidMultiformatAd(
         configId: configId,
         bannerSizes: sizes,
         videoParameters: videoParameters,
         isInterstitial: true,
       );

  /// Runs the Prebid auction and returns targeting keywords for your ad server.
  Future<PrebidBidResponse> fetchDemand() async {
    final result = await _delegate.fetchDemand();
    return PrebidBidResponse(
      resultCode: result.resultCode,
      targetingKeywords: result.targetingKeywords,
    );
  }

  /// Releases native resources held by this ad unit.
  Future<void> destroy() => _delegate.destroy();
}
