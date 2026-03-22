import 'package:flutter/foundation.dart';

import 'ad_enums.dart';
import 'generated/prebid_api.g.dart';

/// Core Prebid Mobile SDK configuration and initialization.
///
/// Use this class to initialize the SDK, set timeouts, configure
/// geo location sharing, debug mode, and other SDK-wide settings.
class PrebidMobile {
  @visibleForTesting
  static PrebidMobileHostApi api = PrebidMobileHostApi();

  /// Initialize the Prebid Mobile SDK.
  ///
  /// [prebidServerUrl] — Your Prebid Server URL.
  /// [accountId] — Your Prebid Server account ID.
  /// [completion] — Called when initialization completes.
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
  static Future<void> setTimeoutMillis(int timeout) async {
    api.setTimeoutMillis(timeout);
  }

  /// Enable or disable geo location sharing.
  static Future<void> setShareGeoLocation(bool share) async {
    api.setShareGeoLocation(share);
  }

  /// Enable or disable PBS debug mode.
  static Future<void> setPbsDebug(bool enabled) async {
    api.setPbsDebug(enabled);
  }

  /// Set custom HTTP headers for bid requests.
  static Future<void> setCustomHeaders(Map<String, String> headers) async {
    api.setCustomHeaders(headers);
  }

  /// Set a stored auction response for testing.
  static Future<void> setStoredAuctionResponse(String response) async {
    api.setStoredAuctionResponse(response);
  }

  /// Clear any previously set stored auction response.
  static Future<void> clearStoredAuctionResponse() async {
    api.clearStoredAuctionResponse();
  }

  /// Add a stored bid response for testing.
  static Future<void> addStoredBidResponse(
    String bidder,
    String responseId,
  ) async {
    api.addStoredBidResponse(bidder, responseId);
  }

  /// Clear all stored bid responses.
  static Future<void> clearStoredBidResponses() async {
    api.clearStoredBidResponses();
  }

  /// Set the log level for the SDK.
  static Future<void> setLogLevel(PrebidLogLevel level) async {
    api.setLogLevel(level.index);
  }

  /// Set the creative factory timeout in milliseconds.
  static Future<void> setCreativeFactoryTimeout(int timeout) async {
    api.setCreativeFactoryTimeout(timeout);
  }

  /// Set the creative factory timeout for pre-render content in milliseconds.
  static Future<void> setCreativeFactoryTimeoutPreRenderContent(
    int timeout,
  ) async {
    api.setCreativeFactoryTimeoutPreRenderContent(timeout);
  }

  /// Set a custom status endpoint URL.
  static Future<void> setCustomStatusEndpoint(String endpoint) async {
    api.setCustomStatusEndpoint(endpoint);
  }
}
