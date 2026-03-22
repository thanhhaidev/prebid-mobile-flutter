import 'dart:ui';

import 'generated/prebid_api.g.dart';

/// Result of an in-stream video bid request.
class PrebidVideoAdBidResponse {
  /// The result code ("prebidDemandFetchSuccess", "prebidDemandNoBids", etc.).
  final String resultCode;

  /// Targeting keywords to pass to the ad server.
  final Map<String, String>? targetingKeywords;

  /// Whether the bid was successful.
  bool get isSuccess => resultCode == 'prebidDemandFetchSuccess';

  const PrebidVideoAdBidResponse({
    required this.resultCode,
    this.targetingKeywords,
  });
}

/// An in-stream video ad unit for original API integration.
///
/// Fetches demand for a VAST video ad via Prebid Server. The returned
/// targeting keywords should be passed to your ad server (e.g., GAM)
/// to request the winning video ad.
///
/// ```dart
/// final videoAd = PrebidInstreamVideoAd(
///   configId: 'your-config-id',
///   size: Size(640, 480),
/// );
///
/// final result = await videoAd.fetchDemand();
/// if (result.isSuccess) {
///   // Pass result.targetingKeywords to your ad server request
/// }
/// ```
class PrebidInstreamVideoAd {
  static final InstreamVideoAdHostApi _api = InstreamVideoAdHostApi();
  static int _nextId = 4000000;

  final int _adId;

  /// The Prebid Server config ID.
  final String configId;

  /// The video player size.
  final Size size;

  /// Creates a [PrebidInstreamVideoAd].
  PrebidInstreamVideoAd({required this.configId, required this.size})
    : _adId = _nextId++;

  /// Fetch demand for this in-stream video ad.
  ///
  /// Returns a [PrebidVideoAdBidResponse] with result code and targeting
  /// keywords to pass to your ad server.
  Future<PrebidVideoAdBidResponse> fetchDemand() async {
    final config = InstreamVideoAdRequestConfig(
      configId: configId,
      width: size.width.toInt(),
      height: size.height.toInt(),
    );

    final result = await _api.fetchDemand(_adId, config);

    Map<String, String>? keywords;
    if (result.targetingKeywords != null) {
      keywords = {};
      result.targetingKeywords!.forEach((key, value) {
        if (key != null && value != null) {
          keywords![key] = value;
        }
      });
    }

    return PrebidVideoAdBidResponse(
      resultCode: result.resultCode,
      targetingKeywords: keywords,
    );
  }

  /// Destroy the ad unit and free resources.
  Future<void> destroy() async {
    _api.destroy(_adId);
  }
}
