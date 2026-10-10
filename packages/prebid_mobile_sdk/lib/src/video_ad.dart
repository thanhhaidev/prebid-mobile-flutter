import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'generated/prebid_api.g.dart';
import 'internal/pigeon_conversions.dart';
import 'internal/session.dart';
import 'video_parameters.dart';

/// Result of an in-stream video bid request.
class PrebidVideoAdBidResponse {
  /// Creates a [PrebidVideoAdBidResponse].
  const PrebidVideoAdBidResponse({
    required this.resultCode,
    this.targetingKeywords,
    this.exp,
  });

  /// The Prebid result code, the same string on Android and iOS:
  /// `prebidDemandFetchSuccess` ([isSuccess]), `prebidDemandNoBids`,
  /// `prebidDemandNoCachedBids`, `prebidDemandTimedOut`,
  /// `prebidNetworkError`, `prebidServerError`, a configuration error
  /// (`prebidInvalidAccountId`, `prebidInvalidConfigId`, `prebidInvalidSize`,
  /// `prebidServerURLInvalid`, `prebidServerNotSpecified`,
  /// `prebidInvalidRequest`) or `prebidSdkNotInitialized`.
  final String resultCode;

  /// Targeting keywords to pass to the ad server.
  final Map<String, String>? targetingKeywords;

  /// Winning bid expiration in seconds (`bid.exp`), if the bid set one.
  final double? exp;

  /// Whether the bid was successful.
  bool get isSuccess => resultCode == 'prebidDemandFetchSuccess';
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
  /// Creates a [PrebidInstreamVideoAd].
  PrebidInstreamVideoAd({
    required this.configId,
    required this.size,
    this.videoParameters,
    this.gpid,
    this.pbAdSlot,
    this.impOrtbConfig,
    this.globalOrtbConfig,
  }) : _adId = _nextId++ {
    releasePreviousIsolateAds();
  }

  /// The platform channel to the native SDK; tests replace it with a mock.
  @visibleForTesting
  static InstreamVideoAdHostApi api = InstreamVideoAdHostApi();
  static int _nextId = 4000000;

  final int _adId;

  /// The Prebid Server config ID.
  final String configId;

  /// The video player size.
  final Size size;

  /// Video signals for the request (mimes, protocols, `plcmt`, duration,
  /// start delay, ...). Buyers usually need at least mimes and protocols.
  final VideoParameters? videoParameters;

  /// Global Placement ID (`imp.ext.gpid`).
  final String? gpid;

  /// Prebid ad slot (`imp.ext.data.pbadslot`).
  final String? pbAdSlot;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp`.
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only (merged over
  /// [PrebidTargeting.setGlobalOrtbConfig]).
  final String? globalOrtbConfig;

  /// Fetch demand for this in-stream video ad.
  ///
  /// Returns a [PrebidVideoAdBidResponse] with result code and targeting
  /// keywords to pass to your ad server.
  Future<PrebidVideoAdBidResponse> fetchDemand() async {
    final config = InstreamVideoAdRequestConfig(
      configId: configId,
      width: size.width.toInt(),
      height: size.height.toInt(),
      videoConfig: videoParameters?.toConfig(),
      gpid: gpid,
      pbAdSlot: pbAdSlot,
      impOrtbConfig: impOrtbConfig,
      globalOrtbConfig: globalOrtbConfig,
    );

    final result = await api.fetchDemand(_adId, config);

    return PrebidVideoAdBidResponse(
      resultCode: result.resultCode,
      targetingKeywords: stringMap(result.targetingKeywords),
      exp: result.exp,
    );
  }

  /// Releases the native ad unit. Call it when the ad unit is no longer
  /// needed (e.g. from `State.dispose`); [fetchDemand] may be called again
  /// afterwards.
  Future<void> destroy() async {
    await api.destroy(_adId);
  }
}
