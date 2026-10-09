import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'ad_enums.dart';
import 'generated/prebid_api.g.dart';
import 'internal/pigeon_conversions.dart';
import 'multiformat_event_router.dart';
import 'native_ad.dart';
import 'native_ad_enums.dart';
import 'prebid_mobile.dart';
import 'video_parameters.dart';

/// Result of a multiformat bid request.
class PrebidMultiformatBidResponse {
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
  ///   errors.
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

  /// Whether the bid was successful.
  bool get isSuccess => resultCode == 'prebidDemandFetchSuccess';

  /// Creates a [PrebidMultiformatBidResponse].
  const PrebidMultiformatBidResponse({
    required this.resultCode,
    this.winningFormat,
    this.targetingKeywords,
    this.nativeAdCacheId,
    this.exp,
    this.topBidFiltered = false,
  });
}

/// A multiformat ad unit that combines banner, video, and native in one
/// bid request. Uses the Prebid SDK's `PrebidAdUnit` + `PrebidRequest` API.
///
/// ```dart
/// final multiformatAd = PrebidMultiformatAd(
///   configId: 'your-config-id',
///   bannerSizes: [Size(300, 250), Size(728, 90)],
///   includeVideo: true,
///   nativeAssets: [
///     NativeAsset.title(length: 90, required: true),
///     NativeAsset.image(imageType: NativeImageType.main),
///     NativeAsset.data(dataType: NativeDataType.sponsored),
///   ],
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
  /// The platform channel to the native SDK; tests replace it with a mock.
  @visibleForTesting
  static MultiformatAdHostApi api = MultiformatAdHostApi();
  static int _nextId = 3000000;

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

  /// Native assets to include in the bid request.
  final List<NativeAsset>? nativeAssets;

  /// Native event trackers.
  final List<NativeEventTracker>? nativeEventTrackers;

  /// Whether this is an interstitial ad.
  final bool isInterstitial;

  /// Whether this is a rewarded ad.
  final bool isRewarded;

  /// Global Placement ID (`imp.ext.gpid`).
  final String? gpid;

  /// Ad position (`imp.banner.pos` / `imp.video.pos`).
  final PrebidAdPosition? adPosition;

  /// Native context, context subtype and placement type, when native is
  /// requested.
  final NativeContextType? nativeContext;

  /// Native context subtype (`contextsubtype`) for the native demand.
  final NativeContextSubType? nativeContextSubType;

  /// Native placement type (`plcmttype`) for the native demand.
  final NativePlacementType? nativePlacementType;

  /// Lets Prebid track the impression when your ad server's interstitial
  /// shows the Prebid creative (Prebid's interstitial impression tracker).
  final bool trackInterstitialImpression;

  /// Called with each auto-refreshed result (see [setAutoRefreshInterval]).
  /// The first auction's result is returned by [fetchDemand].
  final void Function(PrebidMultiformatBidResponse response)? onDemandRefreshed;

  /// Creates a [PrebidMultiformatAd].
  PrebidMultiformatAd({
    required this.configId,
    this.bannerSizes,
    this.videoParameters,
    this.nativeAssets,
    this.nativeEventTrackers,
    this.isInterstitial = false,
    this.isRewarded = false,
    this.gpid,
    this.adPosition,
    this.nativeContext,
    this.nativeContextSubType,
    this.nativePlacementType,
    this.trackInterstitialImpression = false,
    this.onDemandRefreshed,
  }) : _adId = _nextId++ {
    _register();
  }

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
  /// [ArgumentError] when no banner size, video parameters or native asset
  /// is set. Also valid after [destroy].
  Future<PrebidMultiformatBidResponse> fetchDemand() async {
    // Build native config if assets provided
    NativeAdRequestConfig? nativeConfig;
    if (nativeAssets != null && nativeAssets!.isNotEmpty) {
      nativeConfig = NativeAdRequestConfig(
        configId: configId,
        assets: [for (final a in nativeAssets!) a.toConfig()],
        eventTrackers: nativeEventTrackers?.map((t) => t.toConfig()).toList(),
        context: nativeContext?.value,
        contextSubType: nativeContextSubType?.value,
        placementType: nativePlacementType?.value,
      );
    }

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
    if (flatSizes == null && videoConfig == null && nativeConfig == null) {
      throw ArgumentError(
        'Set banner sizes, video parameters or native assets: a request '
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

  static PrebidMultiformatBidResponse _toResponse(MultiformatBidResult result) {
    return PrebidMultiformatBidResponse(
      resultCode: result.resultCode,
      winningFormat: result.winningFormat,
      targetingKeywords: stringMap(result.targetingKeywords),
      nativeAdCacheId: result.nativeAdCacheId,
      exp: result.exp,
      topBidFiltered: result.topBidFiltered ?? false,
    );
  }

  /// Releases the native ad unit (stopping auto-refresh) and stops
  /// delivery to [onDemandRefreshed] until the next [fetchDemand].
  Future<void> destroy() async {
    MultiformatEventRouter.instance.unregister(_adId);
    await api.destroy(_adId);
  }
}
