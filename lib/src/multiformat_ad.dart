import 'dart:ui';

import 'generated/prebid_api.g.dart';
import 'native_ad.dart';

/// Result of a multiformat bid request.
class PrebidMultiformatBidResponse {
  /// The result code ("prebidDemandFetchSuccess", "prebidDemandNoBids", etc.).
  final String resultCode;

  /// The winning ad format ("banner", "video", or "native").
  final String? winningFormat;

  /// Targeting keywords to pass to the ad server.
  final Map<String, String>? targetingKeywords;

  /// Cache ID for native ad data (only if winningFormat == "native").
  final String? nativeAdCacheId;

  /// Whether the bid was successful.
  bool get isSuccess => resultCode == 'prebidDemandFetchSuccess';

  const PrebidMultiformatBidResponse({
    required this.resultCode,
    this.winningFormat,
    this.targetingKeywords,
    this.nativeAdCacheId,
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
class PrebidMultiformatAd {
  static final MultiformatAdHostApi _api = MultiformatAdHostApi();
  static int _nextId = 3000000;

  final int _adId;

  /// The Prebid Server config ID.
  final String configId;

  /// Banner sizes to request (e.g., [Size(300, 250), Size(728, 90)]).
  final List<Size>? bannerSizes;

  /// Whether to include video format in the bid request.
  final bool includeVideo;

  /// Native assets to include in the bid request.
  final List<NativeAsset>? nativeAssets;

  /// Native event trackers.
  final List<NativeEventTracker>? nativeEventTrackers;

  /// Whether this is an interstitial ad.
  final bool isInterstitial;

  /// Whether this is a rewarded ad.
  final bool isRewarded;

  /// Creates a [PrebidMultiformatAd].
  PrebidMultiformatAd({
    required this.configId,
    this.bannerSizes,
    this.includeVideo = false,
    this.nativeAssets,
    this.nativeEventTrackers,
    this.isInterstitial = false,
    this.isRewarded = false,
  }) : _adId = _nextId++;

  /// Fetch demand from Prebid Server for all configured formats.
  ///
  /// Returns a [PrebidMultiformatBidResponse] with the result code,
  /// winning format, targeting keywords, and native cache ID.
  Future<PrebidMultiformatBidResponse> fetchDemand() async {
    // Build native config if assets provided
    NativeAdRequestConfig? nativeConfig;
    if (nativeAssets != null && nativeAssets!.isNotEmpty) {
      nativeConfig = NativeAdRequestConfig(
        configId: configId,
        assets: nativeAssets!.map(_convertAsset).toList(),
        eventTrackers: nativeEventTrackers?.map(_convertTracker).toList(),
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

    final config = MultiformatAdRequestConfig(
      configId: configId,
      bannerSizes: flatSizes,
      includeVideo: includeVideo,
      nativeConfig: nativeConfig,
      isInterstitial: isInterstitial,
      isRewarded: isRewarded,
    );

    final result = await _api.fetchDemand(_adId, config);

    // Convert targeting keywords
    Map<String, String>? keywords;
    if (result.targetingKeywords != null) {
      keywords = {};
      result.targetingKeywords!.forEach((key, value) {
        if (key != null && value != null) {
          keywords![key] = value;
        }
      });
    }

    return PrebidMultiformatBidResponse(
      resultCode: result.resultCode,
      winningFormat: result.winningFormat,
      targetingKeywords: keywords,
      nativeAdCacheId: result.nativeAdCacheId,
    );
  }

  /// Destroy the ad unit and free resources.
  Future<void> destroy() async {
    _api.destroy(_adId);
  }

  NativeAssetConfig _convertAsset(NativeAsset asset) {
    return NativeAssetConfig(
      assetType: asset.type.name,
      required_: asset.required,
      titleLength: asset.titleLength,
      imageType: asset.imageType?.value,
      imageWidth: asset.imageWidth,
      imageHeight: asset.imageHeight,
      imageWidthMin: asset.imageWidthMin,
      imageHeightMin: asset.imageHeightMin,
      dataType: asset.dataType?.value,
      dataLength: asset.dataLength,
    );
  }

  NativeEventTrackerConfig _convertTracker(NativeEventTracker tracker) {
    return NativeEventTrackerConfig(
      eventType: tracker.eventType.value,
      methods: tracker.methods.map((m) => m.value).toList(),
    );
  }
}
