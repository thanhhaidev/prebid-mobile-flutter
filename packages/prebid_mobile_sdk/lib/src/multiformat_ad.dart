import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'ad_enums.dart';
import 'generated/prebid_api.g.dart';
import 'internal/ad_ids.dart';
import 'internal/multiformat_event_router.dart';
import 'internal/pigeon_conversions.dart';
import 'native_parameters.dart';
import 'prebid_mobile.dart';
import 'video_parameters.dart';

/// Result of a multiformat bid request.
class PrebidMultiformatBidResponse {
  /// Creates a [PrebidMultiformatBidResponse].
  const PrebidMultiformatBidResponse({
    required this.resultCode,
    this.winningFormat,
    this.targetingKeywords,
    this.nativeAdCacheId,
    this.exp,
    this.topBidFiltered = false,
    this.events = const {},
    this.receivedAt,
  });

  /// The Prebid result code, the same string on Android and iOS:
  ///
  /// - `prebidDemandFetchSuccess` — a bid won ([isSuccess]).
  /// - `prebidDemandNoBids` — the auction returned no bid.
  /// - `prebidDemandNoCachedBids` — every bid failed Prebid Cache (see
  ///   [PrebidMobile.setFilterOutUncachedBids]).
  /// - `prebidDemandTimedOut` — Prebid Server didn't answer in time.
  /// - `prebidNetworkError`, `prebidServerError` — the request failed.
  /// - `prebidInvalidAccountId`, `prebidInvalidConfigId`,
  ///   `prebidInvalidSize`, `prebidServerURLInvalid`,
  ///   `prebidServerNotSpecified`, `prebidInvalidRequest` — configuration
  ///   errors; Android can also report `prebidInvalidContext`,
  ///   `prebidInvalidAdObject` and `prebidInvalidNativeRequest`.
  /// - `prebidUnknownError`, `prebidInvalidResponseStructure`,
  ///   `prebidInternalSDKError`, `prebidWrongArguments`,
  ///   `prebidNoVastTagInMediaData`, `prebidSDKMisuse` — SDK errors (iOS).
  /// - `prebidSdkNotInitialized` — requested before
  ///   [PrebidMobile.initializeSdk] completed.
  final String resultCode;

  /// The winning bid's format (its `hb_format` keyword): `banner`, `video`
  /// or `native`. `null` when no bid won.
  final String? winningFormat;

  /// Targeting keywords to pass to the ad server.
  final Map<String, String>? targetingKeywords;

  /// Cache ID for native ad data (only if winningFormat == "native").
  final String? nativeAdCacheId;

  /// Winning bid expiration in seconds (`bid.exp`), if the bid set one.
  final double? exp;

  /// Whether the top bid was dropped for a failed Prebid Cache entry and the
  /// next cached bid promoted (see [PrebidMobile.setFilterOutUncachedBids]).
  final bool topBidFiltered;

  /// The winning bid's event URLs, keyed `ext.prebid.events.win` and
  /// `ext.prebid.events.imp`, when Prebid Server sends them; for apps that
  /// render the creative themselves.
  final Map<String, String> events;

  /// Whether the bid was successful.
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

/// A multiformat ad unit that combines banner, video, and native in one
/// bid request. Uses the Prebid SDK's `PrebidAdUnit` + `PrebidRequest` API.
///
/// ```dart
/// final multiformatAd = PrebidMultiformatAd(
///   configId: 'your-config-id',
///   bannerSizes: [Size(300, 250), Size(728, 90)],
///   videoParameters: VideoParameters(mimes: ['video/mp4']),
///   nativeParameters: NativeParameters(
///     assets: [
///       NativeAsset.title(length: 90, required: true),
///       NativeAsset.image(imageType: NativeImageType.main),
///       NativeAsset.data(dataType: NativeDataType.sponsored),
///     ],
///   ),
/// );
///
/// final result = await multiformatAd.fetchDemand();
/// if (result.isSuccess) {
///   switch (result.winningFormat) {
///     case 'banner': /* render banner */
///     case 'video':  /* render video */
///     case 'native': /* render native with result.nativeAdCacheId */
///   }
/// }
/// ```
///
/// [destroy] releases the native ad unit; call it when the ad unit is no
/// longer needed (e.g. from `State.dispose`). The object stays usable:
/// calling [fetchDemand] after [destroy] runs a fresh auction and
/// auto-refreshed results reach [onDemandRefreshed] again.
class PrebidMultiformatAd {
  /// Creates a [PrebidMultiformatAd].
  PrebidMultiformatAd({
    required this.configId,
    this.bannerSizes,
    this.videoParameters,
    this.nativeParameters,
    this.isInterstitial = false,
    this.isRewarded = false,
    this.gpid,
    this.adPosition,
    this.trackInterstitialImpression = false,
    this.bannerApi,
    this.interstitialMinSizePercentage,
    this.supportSKOverlay = false,
    this.pbAdSlot,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.onDemandRefreshed,
  }) : _adId = nextAdId() {
    _register();
  }

  /// The platform channel to the native SDK; tests replace it with a mock.
  @visibleForTesting
  static MultiformatAdHostApi api = MultiformatAdHostApi();

  final int _adId;

  /// The Prebid Server config ID.
  final String configId;

  /// Banner sizes to request (e.g., [Size(300, 250), Size(728, 90)]).
  final List<Size>? bannerSizes;

  /// Video parameters for the bid request.
  ///
  /// If non-null, video format will be included in the request with
  /// the specified MIME types, protocols, playback methods, etc.
  final VideoParameters? videoParameters;

  /// The native request; non-null requests native demand (unset assets
  /// request [NativeParameters.defaultAssets]).
  final NativeParameters? nativeParameters;

  /// Whether this is an interstitial ad.
  final bool isInterstitial;

  /// Whether this is a rewarded ad.
  final bool isRewarded;

  /// Global Placement ID (`imp.ext.gpid`).
  final String? gpid;

  /// Ad position (`imp.banner.pos` / `imp.video.pos`).
  final PrebidAdPosition? adPosition;

  /// Lets Prebid track the impression when your ad server's interstitial
  /// shows the Prebid creative (Prebid's interstitial impression tracker).
  final bool trackInterstitialImpression;

  /// API frameworks the banner supports (OpenRTB `banner.api`), e.g. MRAID.
  final List<VideoApi>? bannerApi;

  /// Minimum interstitial creative size, in percent of the screen (width,
  /// height), for an [isInterstitial] banner request. With no [bannerSizes]
  /// (e.g. a display + video interstitial), the display format is still
  /// requested with this minimum size.
  final Size? interstitialMinSizePercentage;

  /// iOS only: show an SKOverlay for an SKAdNetwork interstitial win.
  final bool supportSKOverlay;

  /// Prebid ad slot (`imp.ext.data.pbadslot`). On Android it applies when
  /// the request has one format (banner, interstitial, rewarded video or
  /// native); Prebid Android's multiformat ad unit has no setter for it.
  final String? pbAdSlot;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp`. On
  /// Android only for a single-format request, as [pbAdSlot].
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only. On Android only for a
  /// single-format request, as [pbAdSlot]; `Targeting.setGlobalOrtbConfig`
  /// applies to every request.
  final String? globalOrtbConfig;

  /// Called with each auto-refreshed result (see [setAutoRefreshInterval]).
  /// The first auction's result is returned by [fetchDemand].
  final void Function(PrebidMultiformatBidResponse response)? onDemandRefreshed;

  /// Routes auto-refreshed results to [onDemandRefreshed]. Idempotent;
  /// [destroy] undoes it and [fetchDemand] redoes it.
  void _register() {
    final callback = onDemandRefreshed;
    if (callback == null) return;
    MultiformatEventRouter.instance.register(
      _adId,
      (result) => callback(_toResponse(result)),
    );
  }

  /// Fetch demand from Prebid Server for all configured formats.
  ///
  /// Returns a [PrebidMultiformatBidResponse] with the result code,
  /// winning format, targeting keywords, and native cache ID. Throws an
  /// [ArgumentError] when no banner size, video parameters or native
  /// parameters are set. Also valid after [destroy].
  Future<PrebidMultiformatBidResponse> fetchDemand() async {
    final nativeConfig = nativeParameters?.toConfig(configId: configId);

    // Flatten banner sizes to [w, h, w, h, ...]
    List<int?>? flatSizes;
    if (bannerSizes != null && bannerSizes!.isNotEmpty) {
      flatSizes = [];
      for (final size in bannerSizes!) {
        flatSizes.add(size.width.toInt());
        flatSizes.add(size.height.toInt());
      }
    }

    // Build video config if parameters provided
    final videoConfig = videoParameters?.toConfig();
    // An interstitial's display format needs no size (see
    // [interstitialMinSizePercentage]).
    final interstitialBanner =
        isInterstitial &&
        (bannerApi != null || interstitialMinSizePercentage != null);
    if (flatSizes == null &&
        !interstitialBanner &&
        videoConfig == null &&
        nativeConfig == null) {
      throw ArgumentError(
        'Set banner sizes, video parameters or native parameters: a request '
        'without any format gets no bids.',
      );
    }

    // Re-register: [destroy] unregisters, and the object may be reused.
    _register();
    final config = MultiformatAdRequestConfig(
      configId: configId,
      bannerSizes: flatSizes,
      videoConfig: videoConfig,
      nativeConfig: nativeConfig,
      isInterstitial: isInterstitial,
      isRewarded: isRewarded,
      gpid: gpid,
      adPosition: adPosition?.value,
      trackInterstitialImpression: trackInterstitialImpression,
      bannerApi: bannerApi?.map((a) => a.value).toList(),
      interstitialMinWidthPercentage: interstitialMinSizePercentage?.width
          .round(),
      interstitialMinHeightPercentage: interstitialMinSizePercentage?.height
          .round(),
      supportSKOverlay: supportSKOverlay,
      pbAdSlot: pbAdSlot,
      impOrtbConfig: impOrtbConfig,
      globalOrtbConfig: globalOrtbConfig,
    );

    return _toResponse(await api.fetchDemand(_adId, config));
  }

  /// Re-runs the auction every [seconds] (Prebid enforces at least 30 s)
  /// after [fetchDemand]; each result goes to [onDemandRefreshed]. Refresh
  /// the ad server's ad with the new targeting keywords yourself.
  Future<void> setAutoRefreshInterval(int seconds) =>
      api.setAutoRefreshInterval(_adId, seconds);

  /// Stops auto-refresh.
  Future<void> stopAutoRefresh() => api.stopAutoRefresh(_adId);

  /// Resumes auto-refresh after [stopAutoRefresh].
  Future<void> resumeAutoRefresh() => api.resumeAutoRefresh(_adId);

  /// Starts Prebid's impression tracker on your ad server's banner view once
  /// it has rendered (e.g. in `google_mobile_ads`' `onAdLoaded`). Prebid
  /// fires the impression (`burl`) only if the view shows this bid's
  /// creative. Returns `false` when there isn't exactly one Google Mobile Ads
  /// banner on screen, since the view can't be identified then.
  ///
  /// iOS tracks the current bid. Prebid Android attaches the view when an
  /// auction starts, so on Android tracking applies from the next auction
  /// (auto-refresh or the next [fetchDemand]).
  Future<bool> activateBannerImpressionTracker() =>
      api.activateBannerImpressionTracker(_adId);

  /// The size of the Prebid creative inside your ad server's banner (the
  /// only Google Mobile Ads banner on screen), read from the rendered
  /// creative once it has loaded; resize the banner to it. `null` when the
  /// creative isn't a Prebid one or there isn't exactly one banner.
  Future<Size?> findPrebidCreativeSize() async {
    final size = await api.findPrebidCreativeSize(_adId);
    if (size == null || size.length != 2) return null;
    return Size(size[0].toDouble(), size[1].toDouble());
  }

  /// iOS only: starts SKAdNetwork's StoreKit flow for a click on the Prebid
  /// creative in your ad server's banner (the only Google Mobile Ads banner
  /// on screen). Returns `false` on Android or when the banner can't be
  /// identified.
  Future<bool> activateBannerSKAdNetwork() =>
      api.activateBannerSKAdNetwork(_adId);

  /// iOS only: starts SKAdNetwork's StoreKit flow for the Prebid creative of
  /// your ad server's interstitial. Does nothing on Android.
  Future<void> activateInterstitialSKAdNetwork() =>
      api.activateInterstitialSKAdNetwork(_adId);

  /// iOS only: shows the SKOverlay of an SKAdNetwork win, if it has one.
  Future<void> activateSKOverlay() => api.activateSKOverlay(_adId);

  /// iOS only: dismisses the SKOverlay shown by [activateSKOverlay].
  Future<void> dismissSKOverlay() => api.dismissSKOverlay(_adId);

  static PrebidMultiformatBidResponse _toResponse(MultiformatBidResult result) {
    return PrebidMultiformatBidResponse(
      resultCode: result.resultCode,
      winningFormat: result.winningFormat,
      targetingKeywords: stringMap(result.targetingKeywords),
      nativeAdCacheId: result.nativeAdCacheId,
      exp: result.exp,
      topBidFiltered: result.topBidFiltered ?? false,
      events: stringMap(result.events) ?? const {},
      receivedAt: DateTime.now(),
    );
  }

  /// Releases the native ad unit (stopping auto-refresh) and stops
  /// delivery to [onDemandRefreshed] until the next [fetchDemand].
  Future<void> destroy() async {
    MultiformatEventRouter.instance.unregister(_adId);
    await api.destroy(_adId);
  }
}
