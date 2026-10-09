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
/// Receives every Prebid Server bid request / response pair (as JSON
/// strings) while registered via [PrebidMobile.setEventListener].
typedef PrebidBidResponseListener =
    void Function(String? request, String? response);

class PrebidMobile {
  @visibleForTesting
  static PrebidMobileHostApi api = PrebidMobileHostApi();

  static bool _initialized = false;

  /// Whether [initializeSdk] has completed with a usable status
  /// ([InitializationStatus.succeeded] or
  /// [InitializationStatus.serverStatusWarning]).
  static bool get isSdkInitialized => _initialized;

  /// Initialize the Prebid Mobile SDK.
  ///
  /// Must be called once before loading any ads. Typically called during
  /// app startup (e.g., in `main()`).
  ///
  /// - [prebidServerUrl] — Your Prebid Server endpoint URL
  ///   (e.g., `https://prebid-server-test-j.prebid.org/openrtb2/auction`).
  /// - [accountId] — Your Prebid Server account ID.
  /// - [nonTrackingUrl] — iOS only: the auction endpoint used when the user
  ///   has not authorized tracking (ATT), for a server that must not receive
  ///   identifiers.
  /// - [completion] — Optional callback invoked with the [InitializationStatus]
  ///   and an error message (if any).
  static Future<void> initializeSdk({
    required String prebidServerUrl,
    required String accountId,
    String? nonTrackingUrl,
    void Function(InitializationStatus status, String? error)? completion,
  }) async {
    final result = await api.initializeSdk(
      prebidServerUrl,
      accountId,
      nonTrackingUrl,
    );
    final status = switch (result.status) {
      'succeeded' => InitializationStatus.succeeded,
      'serverStatusWarning' => InitializationStatus.serverStatusWarning,
      _ => InitializationStatus.failed,
    };
    _initialized = status != InitializationStatus.failed;
    completion?.call(status, result.error);
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

  /// Assign sequential IDs (1, 2, …) to native request assets.
  ///
  /// Required when the native creative refers to assets by ID — Prebid Server
  /// drops a bid whose response assets don't match an ID in the request.
  /// Default `false`.
  static Future<void> setShouldAssignNativeAssetId(bool assign) async {
    api.setShouldAssignNativeAssetId(assign);
  }

  /// Drop bids whose Prebid Cache entry failed and promote the next cached
  /// bid (Prebid 3.4). When no cached bid remains the result code is
  /// `prebidDemandNoCachedBids`. Applies to the Original API. Default `false`.
  static Future<void> setFilterOutUncachedBids(bool filter) async {
    api.setFilterOutUncachedBids(filter);
  }

  /// Where external user IDs are sent: `user.eids` (OpenRTB 2.6),
  /// `user.ext.eids` (2.5) or both (default). Prebid 3.4.
  static Future<void> setEidsPlacement(PrebidEidsPlacement placement) async {
    api.setEidsPlacement(placement.name);
  }

  /// Ask Prebid Server to include `hb_*` winner keywords
  /// (`ext.prebid.targeting.includewinners`).
  static Future<void> setIncludeWinners(bool include) async {
    api.setIncludeWinners(include);
  }

  /// Ask Prebid Server to include per-bidder `hb_*_<bidder>` keywords
  /// (`ext.prebid.targeting.includebidderkeys`).
  static Future<void> setIncludeBidderKeys(bool include) async {
    api.setIncludeBidderKeys(include);
  }

  /// Sets the stored auction-settings id (`ext.prebid.storedrequest.id` at
  /// the request level). `null` clears it.
  static Future<void> setAuctionSettingsId(String? settingsId) async {
    api.setAuctionSettingsId(settingsId);
  }

  /// Skips the Prebid Server status request during [initializeSdk] (e.g. a
  /// server without a status endpoint). Call it before [initializeSdk].
  static Future<void> setDisableStatusCheck(bool disable) async {
    await api.setDisableStatusCheck(disable);
  }

  /// Registers [listener] to receive every Prebid Server bid request and
  /// response as JSON (Prebid's `PrebidEventDelegate`). Pass `null` to stop.
  ///
  /// Useful for debugging and analytics; the payloads can be large.
  static Future<void> setEventListener(
    PrebidBidResponseListener? listener,
  ) async {
    _PrebidEventReceiver.instance.listener = listener;
    await api.setEventDelegateEnabled(listener != null);
  }

  // ---------------------------------------------------------------------------
  // SharedID
  // ---------------------------------------------------------------------------

  /// Adds Prebid's first-party SharedID (`pubcid.org`) to `user.eids`.
  /// Consult your legal team before enabling. Default `false`.
  static Future<void> setSendSharedId(bool send) async {
    api.setSendSharedId(send);
  }

  /// The current SharedID. It stays stable across sessions while local
  /// storage access is allowed, until [resetSharedId].
  static Future<ExternalUserId?> getSharedId() async {
    final d = await api.getSharedId();
    if (d == null) return null;
    return ExternalUserId(
      source: d.source,
      identifier: d.identifier,
      atype: d.atype,
    );
  }

  /// Clears the stored SharedID; the next one is freshly generated.
  static Future<void> resetSharedId() async {
    api.resetSharedId();
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
            inserter: u.inserter,
            matcher: u.matcher,
            mm: u.mm,
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
            ext: d.ext?.map((k, v) => MapEntry(k ?? '', v)),
            inserter: d.inserter,
            matcher: d.matcher,
            mm: d.mm,
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

/// Owns the [PrebidEventFlutterApi] channel and forwards to the listener set
/// with [PrebidMobile.setEventListener].
class _PrebidEventReceiver implements PrebidEventFlutterApi {
  _PrebidEventReceiver._() {
    PrebidEventFlutterApi.setUp(this);
  }

  static final _PrebidEventReceiver instance = _PrebidEventReceiver._();

  PrebidBidResponseListener? listener;

  @override
  Future<void> onBidResponse(String? request, String? response) async {
    listener?.call(request, response);
  }
}
