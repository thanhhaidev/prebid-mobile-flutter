import 'package:flutter/foundation.dart';

import 'ad_enums.dart';
import 'external_user_id.dart';
import 'generated/prebid_api.g.dart';

/// Core Prebid Mobile SDK configuration and initialization.
///
/// This static class is the entry point for:
/// - **Initializing the SDK** with your Prebid Server URL and account ID.
/// - **Configuring global settings** such as timeouts, geo location, debug mode, and log level.
/// - **Managing stored responses** for deterministic testing.
/// - **External User IDs** for third-party identity modules.
///
/// All methods are static and can be called from anywhere after the SDK is initialized.
///
/// ## Example
///
/// ```dart
/// // Initialize
/// await PrebidMobile.initializeSdk(
///   prebidServerUrl: 'https://your-pbs.com/openrtb2/auction',
///   accountId: 'your-account-id',
///   completion: (status, error) {
///     debugPrint('SDK status: $status');
///   },
/// );
///
/// // Configure
/// await PrebidMobile.setTimeoutMillis(3000);
/// await PrebidMobile.setShareGeoLocation(true);
/// await PrebidMobile.setPbsDebug(true);
/// await PrebidMobile.setLogLevel(PrebidLogLevel.debug);
/// ```
class PrebidMobile {
  @visibleForTesting
  static PrebidMobileHostApi api = PrebidMobileHostApi();

  /// Initialize the Prebid Mobile SDK.
  ///
  /// Must be called once before loading any ads. Typically called during
  /// app startup (e.g., in `main()`).
  ///
  /// - [prebidServerUrl] — Your Prebid Server endpoint URL
  ///   (e.g., `https://prebid-server-test-j.prebid.org/openrtb2/auction`).
  /// - [accountId] — Your Prebid Server account ID.
  /// - [completion] — Optional callback invoked with the [InitializationStatus]
  ///   and an error message (if any).
  static Future<void> initializeSdk({
    required String prebidServerUrl,
    required String accountId,
    void Function(InitializationStatus status, String? error)? completion,
  }) async {
    final result = await api.initializeSdk(prebidServerUrl, accountId);

    if (completion != null) {
      final status = switch (result.status) {
        'succeeded' => InitializationStatus.succeeded,
        'serverStatusWarning' => InitializationStatus.serverStatusWarning,
        _ => InitializationStatus.failed,
      };
      completion(status, result.error);
    }
  }

  /// Set the timeout for bid requests in milliseconds.
  ///
  /// If the Prebid Server does not respond within [timeout] ms,
  /// the bid request will fail with [PrebidErrorCode.timeout].
  ///
  /// Default value is determined by the native SDK.
  static Future<void> setTimeoutMillis(int timeout) async {
    api.setTimeoutMillis(timeout);
  }

  /// Enable or disable sharing the device's geo location in bid requests.
  ///
  /// When enabled, the SDK includes `device.geo` fields (latitude, longitude)
  /// in the OpenRTB request, which can improve bid rates.
  static Future<void> setShareGeoLocation(bool share) async {
    api.setShareGeoLocation(share);
  }

  /// Enable or disable PBS debug mode.
  ///
  /// When enabled, the SDK adds `"test": 1` to outgoing bid requests,
  /// which tells the Prebid Server to return test bids (useful for
  /// development and QA).
  static Future<void> setPbsDebug(bool enabled) async {
    api.setPbsDebug(enabled);
  }

  /// Set custom HTTP headers to include in every bid request.
  ///
  /// Use this for authentication tokens, custom tracking headers,
  /// or server-specific configuration.
  static Future<void> setCustomHeaders(Map<String, String> headers) async {
    api.setCustomHeaders(headers);
  }

  /// Set a stored auction response ID for deterministic testing.
  ///
  /// When set, the Prebid Server returns a pre-configured response
  /// instead of running a live auction. Useful for QA and automated testing.
  ///
  /// Call [clearStoredAuctionResponse] to remove it.
  static Future<void> setStoredAuctionResponse(String response) async {
    api.setStoredAuctionResponse(response);
  }

  /// Remove any previously set stored auction response.
  ///
  /// After calling this, subsequent bid requests will go through
  /// the normal live auction flow.
  static Future<void> clearStoredAuctionResponse() async {
    api.clearStoredAuctionResponse();
  }

  /// Add a stored bid response for a specific bidder.
  ///
  /// - [bidder] — The bidder name (e.g., `"appnexus"`).
  /// - [responseId] — The stored response ID configured on Prebid Server.
  static Future<void> addStoredBidResponse(
    String bidder,
    String responseId,
  ) async {
    api.addStoredBidResponse(bidder, responseId);
  }

  /// Remove all stored bid responses.
  static Future<void> clearStoredBidResponses() async {
    api.clearStoredBidResponses();
  }

  /// Set the SDK log verbosity level.
  ///
  /// See [PrebidLogLevel] for available levels.
  /// The default level is platform-specific.
  static Future<void> setLogLevel(PrebidLogLevel level) async {
    api.setLogLevel(level.index);
  }

  /// Set the creative factory timeout for banner ads in milliseconds.
  ///
  /// This controls how long the SDK waits for an HTML creative to
  /// load before considering it failed.
  static Future<void> setCreativeFactoryTimeout(int timeout) async {
    api.setCreativeFactoryTimeout(timeout);
  }

  /// Set the creative factory timeout for pre-render video content in milliseconds.
  ///
  /// This controls how long the SDK waits for a video creative
  /// to pre-render before considering it failed.
  static Future<void> setCreativeFactoryTimeoutPreRenderContent(
    int timeout,
  ) async {
    api.setCreativeFactoryTimeoutPreRenderContent(timeout);
  }

  /// Override the default Prebid Server status endpoint URL.
  ///
  /// The SDK calls this endpoint during initialization to verify
  /// the server is reachable and configured correctly.
  static Future<void> setCustomStatusEndpoint(String endpoint) async {
    api.setCustomStatusEndpoint(endpoint);
  }

  // ---------------------------------------------------------------------------
  // External User IDs
  // ---------------------------------------------------------------------------

  /// Set external user IDs from third-party identity modules.
  ///
  /// These IDs are included in every bid request, enabling bidders to
  /// better identify users and improve fill rates.
  ///
  /// ```dart
  /// await PrebidMobile.setExternalUserIds([
  ///   ExternalUserId(source: 'uidapi.com', identifier: 'uid2-abc', atype: 3),
  ///   ExternalUserId(source: 'sharedid.org', identifier: 'shared-xyz', atype: 1),
  /// ]);
  /// ```
  static Future<void> setExternalUserIds(List<ExternalUserId> userIds) async {
    final data = userIds
        .map(
          (u) => ExternalUserIdData(
            source: u.source,
            identifier: u.identifier,
            atype: u.atype,
            ext: u.ext?.map((k, v) => MapEntry(k, v)),
          ),
        )
        .toList();
    api.setExternalUserIds(data);
  }

  /// Get all currently set external user IDs.
  static Future<List<ExternalUserId>> getExternalUserIds() async {
    final data = await api.getExternalUserIds();
    return data
        .map(
          (d) => ExternalUserId(
            source: d.source,
            identifier: d.identifier,
            atype: d.atype,
          ),
        )
        .toList();
  }

  /// Clear all external user IDs.
  static Future<void> clearExternalUserIds() async {
    api.clearExternalUserIds();
  }

  // ---------------------------------------------------------------------------
  // SDK Version
  // ---------------------------------------------------------------------------

  /// Get the native Prebid Mobile SDK version string.
  ///
  /// Returns the version of the underlying Android or iOS Prebid SDK.
  static Future<String> getSdkVersion() async {
    return api.getSdkVersion();
  }
}
