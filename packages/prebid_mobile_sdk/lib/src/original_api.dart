import 'dart:ui' show Size;

import 'ad_enums.dart';
import 'multiformat_ad.dart';
import 'native_ad.dart';
import 'native_parameters.dart';
import 'video_parameters.dart';

/// Result of an **Original API** bid request.
///
/// In the Original API integration the Prebid SDK only runs the auction and
/// returns [targetingKeywords]; your primary ad server SDK (e.g. Google Ad
/// Manager via `google_mobile_ads`) renders the ad. Pass [targetingKeywords]
/// to your ad request as custom targeting.
class PrebidBidResponse {
  /// Creates a [PrebidBidResponse].
  const PrebidBidResponse({
    required this.resultCode,
    this.targetingKeywords,
    this.exp,
    this.topBidFiltered = false,
    this.events = const {},
    this.receivedAt,
  });

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

  /// Winning bid expiration in seconds (`bid.exp`), if the bid set one.
  final double? exp;

  /// Whether the top bid was dropped for a failed Prebid Cache entry and the
  /// next cached bid promoted.
  final bool topBidFiltered;

  /// The winning bid's event URLs; see [PrebidMultiformatBidResponse.events].
  final Map<String, String> events;

  /// Whether the auction returned a winning bid.
  bool get isSuccess => resultCode == 'prebidDemandFetchSuccess';

  /// When the plugin received this response; with [exp] it gives
  /// [expiresAt].
  final DateTime? receivedAt;

  /// When the winning bid expires: [receivedAt] plus [exp], or `null` when
  /// the bid set no `exp`.
  DateTime? get expiresAt {
    final at = receivedAt;
    final seconds = exp;
    if (at == null || seconds == null) return null;
    return at.add(Duration(milliseconds: (seconds * 1000).round()));
  }

  /// Whether [expiresAt] has passed. A full-screen ad is often loaded long
  /// before it shows: fetch demand again rather than load your ad server's
  /// ad with expired keywords. `false` when the bid set no `exp`.
  bool get isExpired {
    final at = expiresAt;
    return at != null && !DateTime.now().isBefore(at);
  }
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
      exp: r.exp,
      topBidFiltered: r.topBidFiltered,
      events: r.events,
      receivedAt: r.receivedAt,
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
  /// Creates a [PrebidBannerAdUnit]. [onDemandRefreshed] receives each
  /// auto-refreshed result (see [setAutoRefreshInterval]).
  PrebidBannerAdUnit({
    required this.configId,
    required this.sizes,
    this.adPosition,
    this.gpid,
    this.pbAdSlot,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    void Function(PrebidBidResponse response)? onDemandRefreshed,
  }) : _delegate = PrebidMultiformatAd(
         configId: configId,
         bannerSizes: sizes,
         adPosition: adPosition,
         gpid: gpid,
         pbAdSlot: pbAdSlot,
         impOrtbConfig: impOrtbConfig,
         globalOrtbConfig: globalOrtbConfig,
         onDemandRefreshed: onDemandRefreshed == null
             ? null
             : (r) => onDemandRefreshed(_bidResponse(r)),
       );

  /// The Prebid Server stored impression config ID.
  final String configId;

  /// Banner sizes to request (e.g. `[Size(300, 250)]`).
  final List<Size> sizes;

  /// Ad position on screen (`imp.banner.pos`).
  final PrebidAdPosition? adPosition;

  /// Global Placement ID (`imp.ext.gpid`).
  final String? gpid;

  /// Prebid ad slot (`imp.ext.data.pbadslot`).
  final String? pbAdSlot;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp`.
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only (merged over
  /// `PrebidTargeting.setGlobalOrtbConfig`).
  final String? globalOrtbConfig;

  @override
  final PrebidMultiformatAd _delegate;

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
  /// Creates a [PrebidInterstitialAdUnit].
  PrebidInterstitialAdUnit({
    required this.configId,
    this.sizes,
    this.videoParameters,
    this.trackImpression = false,
    this.gpid,
    this.minSizePercentage,
    this.pbAdSlot,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    void Function(PrebidBidResponse response)? onDemandRefreshed,
  }) : _delegate = PrebidMultiformatAd(
         configId: configId,
         bannerSizes: sizes,
         videoParameters: videoParameters,
         gpid: gpid,
         interstitialMinSizePercentage: minSizePercentage,
         pbAdSlot: pbAdSlot,
         impOrtbConfig: impOrtbConfig,
         globalOrtbConfig: globalOrtbConfig,
         isInterstitial: true,
         trackInterstitialImpression: trackImpression,
         onDemandRefreshed: onDemandRefreshed == null
             ? null
             : (r) => onDemandRefreshed(_bidResponse(r)),
       );

  /// The Prebid Server stored impression config ID.
  final String configId;

  /// Display interstitial sizes (optional if [videoParameters] is set).
  final List<Size>? sizes;

  /// Video parameters for a video interstitial (optional if [sizes] is set).
  final VideoParameters? videoParameters;

  /// Lets Prebid track the impression (`burl`) when your ad server's
  /// interstitial shows this bid's creative.
  final bool trackImpression;

  /// Global Placement ID (`imp.ext.gpid`).
  final String? gpid;

  /// Minimum display creative size, in percent of the screen (width,
  /// height). Requests the display format even without [sizes].
  final Size? minSizePercentage;

  /// Prebid ad slot (`imp.ext.data.pbadslot`).
  final String? pbAdSlot;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp`.
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only (merged over
  /// `PrebidTargeting.setGlobalOrtbConfig`).
  final String? globalOrtbConfig;

  @override
  final PrebidMultiformatAd _delegate;

  /// Runs the Prebid auction and returns targeting keywords for your ad server.
  Future<PrebidBidResponse> fetchDemand() async =>
      _bidResponse(await _delegate.fetchDemand());
}

/// A rewarded video ad unit for the **Original API** integration: Prebid runs
/// the auction and returns targeting keywords for your ad server to render
/// the rewarded ad (use [PrebidRewardedAd] for Prebid rendering instead).
///
/// ```dart
/// final adUnit = PrebidRewardedAdUnit(
///   configId: 'your-config-id',
///   videoParameters: const VideoParameters(mimes: ['video/mp4']),
/// );
/// final response = await adUnit.fetchDemand();
/// // RewardedAd.loadWithAdManagerAdRequest(
/// //   adManagerRequest: AdManagerAdRequest(customTargeting: response.targetingKeywords ?? {}),
/// // );
/// ```
///
/// Call [destroy] when the unit is no longer needed (e.g. from
/// `State.dispose`); [fetchDemand] may be called again afterwards.
class PrebidRewardedAdUnit with _AutoRefresh {
  /// Creates a [PrebidRewardedAdUnit].
  PrebidRewardedAdUnit({
    required this.configId,
    required this.videoParameters,
    this.trackImpression = false,
    this.gpid,
    this.pbAdSlot,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    void Function(PrebidBidResponse response)? onDemandRefreshed,
  }) : _delegate = PrebidMultiformatAd(
         configId: configId,
         videoParameters: videoParameters,
         gpid: gpid,
         pbAdSlot: pbAdSlot,
         impOrtbConfig: impOrtbConfig,
         globalOrtbConfig: globalOrtbConfig,
         isInterstitial: true,
         isRewarded: true,
         trackInterstitialImpression: trackImpression,
         onDemandRefreshed: onDemandRefreshed == null
             ? null
             : (r) => onDemandRefreshed(_bidResponse(r)),
       );

  /// The Prebid Server stored impression config ID.
  final String configId;

  /// The rewarded video's OpenRTB parameters.
  final VideoParameters videoParameters;

  /// Lets Prebid track the impression (`burl`) when your ad server's
  /// rewarded ad shows this bid's creative.
  final bool trackImpression;

  /// Global Placement ID (`imp.ext.gpid`).
  final String? gpid;

  /// Prebid ad slot (`imp.ext.data.pbadslot`).
  final String? pbAdSlot;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp`.
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only (merged over
  /// `PrebidTargeting.setGlobalOrtbConfig`).
  final String? globalOrtbConfig;

  @override
  final PrebidMultiformatAd _delegate;

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
  /// Creates a [PrebidNativeAdUnit].
  PrebidNativeAdUnit({
    required this.configId,
    this.nativeParameters = const NativeParameters(),
    this.gpid,
    this.pbAdSlot,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    void Function(PrebidNativeBidResponse response)? onDemandRefreshed,
  }) : _delegate = PrebidMultiformatAd(
         configId: configId,
         nativeParameters: nativeParameters,
         gpid: gpid,
         pbAdSlot: pbAdSlot,
         impOrtbConfig: impOrtbConfig,
         globalOrtbConfig: globalOrtbConfig,
         onDemandRefreshed: onDemandRefreshed == null
             ? null
             : (r) => onDemandRefreshed(_nativeResponse(r)),
       );

  /// The Prebid Server stored impression config ID.
  final String configId;

  /// The native request: assets, event trackers, context and options.
  /// Unset assets request [NativeParameters.defaultAssets].
  final NativeParameters nativeParameters;

  /// Global Placement ID (`imp.ext.gpid`).
  final String? gpid;

  /// Prebid ad slot (`imp.ext.data.pbadslot`).
  final String? pbAdSlot;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp`.
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only (merged over
  /// `PrebidTargeting.setGlobalOrtbConfig`).
  final String? globalOrtbConfig;

  @override
  final PrebidMultiformatAd _delegate;

  /// Runs the Prebid auction and returns targeting keywords for your ad server.
  Future<PrebidNativeBidResponse> fetchDemand() async =>
      _nativeResponse(await _delegate.fetchDemand());

  static PrebidNativeBidResponse _nativeResponse(
    PrebidMultiformatBidResponse r,
  ) => PrebidNativeBidResponse(
    resultCode: r.resultCode,
    targetingKeywords: r.targetingKeywords,
    exp: r.exp,
    topBidFiltered: r.topBidFiltered,
    events: r.events,
    nativeAdCacheId: r.nativeAdCacheId,
  );
}

/// Result of an Original API native bid request.
class PrebidNativeBidResponse extends PrebidBidResponse {
  /// Creates a [PrebidNativeBidResponse].
  const PrebidNativeBidResponse({
    required super.resultCode,
    super.targetingKeywords,
    super.exp,
    super.topBidFiltered,
    super.events,
    this.nativeAdCacheId,
  });

  /// Native cache ID returned by Prebid, when native demand wins; show the
  /// ad with [PrebidNativeAd.loadFromCacheId].
  final String? nativeAdCacheId;
}
