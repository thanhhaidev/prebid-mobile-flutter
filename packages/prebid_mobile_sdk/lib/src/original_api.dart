import 'dart:ui' show Size;

import 'ad_enums.dart';
import 'multiformat_ad.dart';
import 'native_ad.dart';
import 'native_ad_enums.dart';
import 'video_parameters.dart';

/// Result of an **Original API** bid request.
///
/// In the Original API integration the Prebid SDK only runs the auction and
/// returns [targetingKeywords]; your primary ad server SDK (e.g. Google Ad
/// Manager via `google_mobile_ads`) renders the ad. Pass [targetingKeywords]
/// to your ad request as custom targeting.
class PrebidBidResponse {
  /// The Prebid result code, the same string on Android and iOS. One of
  /// `prebidDemandFetchSuccess` ([isSuccess]), `prebidDemandNoBids`,
  /// `prebidDemandNoCachedBids`, `prebidDemandTimedOut`,
  /// `prebidNetworkError`, `prebidServerError`, `prebidInvalidAccountId`,
  /// `prebidInvalidConfigId`, `prebidInvalidSize`, `prebidServerURLInvalid`,
  /// `prebidServerNotSpecified`, `prebidInvalidRequest` or
  /// `prebidSdkNotInitialized`; see
  /// [PrebidMultiformatBidResponse.resultCode] for their meaning.
  final String resultCode;

  /// Bid-winning targeting keywords to hand to your ad server, or `null`/empty
  /// when there was no bid.
  final Map<String, String>? targetingKeywords;

  /// Whether the auction returned a winning bid.
  bool get isSuccess => resultCode == 'prebidDemandFetchSuccess';

  /// Creates a [PrebidBidResponse].
  const PrebidBidResponse({required this.resultCode, this.targetingKeywords});
}

/// Auto-refresh shared by the Original API ad units: after [fetchDemand]
/// Prebid re-runs the auction every interval and reports each result to the
/// unit's `onDemandRefreshed`; refresh your ad server's ad with the new
/// targeting keywords.
mixin _AutoRefresh {
  PrebidMultiformatAd get _delegate;

  /// Re-runs the auction every [seconds] (Prebid enforces at least 30 s).
  Future<void> setAutoRefreshInterval(int seconds) =>
      _delegate.setAutoRefreshInterval(seconds);

  /// Stops auto-refresh.
  Future<void> stopAutoRefresh() => _delegate.stopAutoRefresh();

  /// Resumes auto-refresh after [stopAutoRefresh].
  Future<void> resumeAutoRefresh() => _delegate.resumeAutoRefresh();

  /// Releases the native ad unit and stops auto-refresh. Call it when the
  /// unit is no longer needed (e.g. from `State.dispose`); a later
  /// `fetchDemand` reuses the unit.
  Future<void> destroy() => _delegate.destroy();
}

PrebidBidResponse _bidResponse(PrebidMultiformatBidResponse r) =>
    PrebidBidResponse(
      resultCode: r.resultCode,
      targetingKeywords: r.targetingKeywords,
    );

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
///
/// Call [destroy] when the unit is no longer needed (e.g. from
/// `State.dispose`); [fetchDemand] may be called again afterwards.
class PrebidBannerAdUnit with _AutoRefresh {
  /// The Prebid Server stored impression config ID.
  final String configId;

  /// Banner sizes to request (e.g. `[Size(300, 250)]`).
  final List<Size> sizes;

  /// Ad position on screen (`imp.banner.pos`).
  final PrebidAdPosition? adPosition;

  @override
  final PrebidMultiformatAd _delegate;

  /// Creates a [PrebidBannerAdUnit]. [onDemandRefreshed] receives each
  /// auto-refreshed result (see [setAutoRefreshInterval]).
  PrebidBannerAdUnit({
    required this.configId,
    required this.sizes,
    this.adPosition,
    void Function(PrebidBidResponse response)? onDemandRefreshed,
  }) : _delegate = PrebidMultiformatAd(
         configId: configId,
         bannerSizes: sizes,
         adPosition: adPosition,
         onDemandRefreshed: onDemandRefreshed == null
             ? null
             : (r) => onDemandRefreshed(_bidResponse(r)),
       );

  /// Runs the Prebid auction and returns targeting keywords for your ad server.
  Future<PrebidBidResponse> fetchDemand() async =>
      _bidResponse(await _delegate.fetchDemand());

  /// Starts Prebid's impression tracker on your ad server's banner once it
  /// has rendered (e.g. in `google_mobile_ads`' `onAdLoaded`); Prebid fires
  /// the impression only if the banner shows this bid's creative. Returns
  /// `false` when there isn't exactly one Google Mobile Ads banner on screen.
  /// iOS tracks the current bid; Prebid Android attaches the view when an
  /// auction starts, so on Android tracking applies from the next auction
  /// (auto-refresh or the next [fetchDemand]).
  Future<bool> activateImpressionTracker() =>
      _delegate.activateBannerImpressionTracker();
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
///
/// Call [destroy] when the unit is no longer needed (e.g. from
/// `State.dispose`); [fetchDemand] may be called again afterwards.
class PrebidInterstitialAdUnit with _AutoRefresh {
  /// The Prebid Server stored impression config ID.
  final String configId;

  /// Display interstitial sizes (optional if [videoParameters] is set).
  final List<Size>? sizes;

  /// Video parameters for a video interstitial (optional if [sizes] is set).
  final VideoParameters? videoParameters;

  /// Lets Prebid track the impression (`burl`) when your ad server's
  /// interstitial shows this bid's creative.
  final bool trackImpression;

  @override
  final PrebidMultiformatAd _delegate;

  /// Creates a [PrebidInterstitialAdUnit].
  PrebidInterstitialAdUnit({
    required this.configId,
    this.sizes,
    this.videoParameters,
    this.trackImpression = false,
    void Function(PrebidBidResponse response)? onDemandRefreshed,
  }) : _delegate = PrebidMultiformatAd(
         configId: configId,
         bannerSizes: sizes,
         videoParameters: videoParameters,
         isInterstitial: true,
         trackInterstitialImpression: trackImpression,
         onDemandRefreshed: onDemandRefreshed == null
             ? null
             : (r) => onDemandRefreshed(_bidResponse(r)),
       );

  /// Runs the Prebid auction and returns targeting keywords for your ad server.
  Future<PrebidBidResponse> fetchDemand() async =>
      _bidResponse(await _delegate.fetchDemand());
}

/// A native ad unit for the **Original API** integration: Prebid runs the
/// auction and returns targeting keywords plus the native cache ID, while your
/// ad server SDK owns rendering.
///
/// Call [destroy] when the unit is no longer needed (e.g. from
/// `State.dispose`); [fetchDemand] may be called again afterwards.
class PrebidNativeAdUnit with _AutoRefresh {
  /// The Prebid Server stored impression config ID.
  final String configId;

  /// Native assets to request.
  final List<NativeAsset> assets;

  /// Native event trackers.
  final List<NativeEventTracker>? eventTrackers;

  /// Native context, context subtype and placement type.
  final NativeContextType? context;

  /// Native context subtype (`contextsubtype`).
  final NativeContextSubType? contextSubType;

  /// Native placement type (`plcmttype`).
  final NativePlacementType? placementType;

  @override
  final PrebidMultiformatAd _delegate;

  /// Creates a [PrebidNativeAdUnit].
  PrebidNativeAdUnit({
    required this.configId,
    required this.assets,
    this.eventTrackers,
    this.context,
    this.contextSubType,
    this.placementType,
    void Function(PrebidNativeBidResponse response)? onDemandRefreshed,
  }) : _delegate = PrebidMultiformatAd(
         configId: configId,
         nativeAssets: assets,
         nativeEventTrackers: eventTrackers,
         nativeContext: context,
         nativeContextSubType: contextSubType,
         nativePlacementType: placementType,
         onDemandRefreshed: onDemandRefreshed == null
             ? null
             : (r) => onDemandRefreshed(_nativeResponse(r)),
       );

  /// Runs the Prebid auction and returns targeting keywords for your ad server.
  Future<PrebidNativeBidResponse> fetchDemand() async =>
      _nativeResponse(await _delegate.fetchDemand());

  static PrebidNativeBidResponse _nativeResponse(
    PrebidMultiformatBidResponse r,
  ) => PrebidNativeBidResponse(
    resultCode: r.resultCode,
    targetingKeywords: r.targetingKeywords,
    nativeAdCacheId: r.nativeAdCacheId,
  );
}

/// Result of an Original API native bid request.
class PrebidNativeBidResponse extends PrebidBidResponse {
  /// Native cache ID returned by Prebid, when native demand wins.
  final String? nativeAdCacheId;

  /// Creates a [PrebidNativeBidResponse].
  const PrebidNativeBidResponse({
    required super.resultCode,
    super.targetingKeywords,
    this.nativeAdCacheId,
  });
}
