import 'package:flutter/foundation.dart';

import 'ad_enums.dart';
import 'external_user_id.dart';
import 'generated/prebid_api.g.dart';

/// Receives each Prebid Server bid request and response (JSON strings)
/// while registered with [PrebidMobile.setEventListener].
typedef PrebidBidResponseListener =
    void Function(String? request, String? response);

/// Initializes the Prebid Mobile SDK and holds its global settings.
///
/// Call [initializeSdk] once at startup, and await it before loading ads.
/// The other methods configure every request made afterwards: timeouts,
/// Prebid Server flags, stored responses, external user IDs and logging.
///
/// ```dart
/// await PrebidMobile.initializeSdk(
///   prebidServerUrl: 'https://prebid-server.example.com/openrtb2/auction',
///   accountId: 'your-account-id',
/// );
/// await PrebidMobile.setTimeoutMillis(3000);
/// ```
class PrebidMobile {
  // Static members only.
  PrebidMobile._();

  /// The platform channel to the native SDK; tests replace it with a mock.
  @visibleForTesting
  static PrebidMobileHostApi api = PrebidMobileHostApi();

  static bool _initialized = false;

  /// Whether [initializeSdk] has completed with a usable status
  /// ([PrebidInitializationStatus.succeeded] or
  /// [PrebidInitializationStatus.serverStatusWarning]).
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
  /// - [completion] — Optional callback invoked with the [PrebidInitializationStatus]
  ///   and an error message (if any).
  static Future<void> initializeSdk({
    required String prebidServerUrl,
    required String accountId,
    String? nonTrackingUrl,
    void Function(PrebidInitializationStatus status, String? error)? completion,
  }) async {
    final result = await api.initializeSdk(
      prebidServerUrl,
      accountId,
      nonTrackingUrl,
    );
    final status = switch (result.status) {
      'succeeded' => PrebidInitializationStatus.succeeded,
      'serverStatusWarning' => PrebidInitializationStatus.serverStatusWarning,
      _ => PrebidInitializationStatus.failed,
    };
    _initialized = status != PrebidInitializationStatus.failed;
    completion?.call(status, result.error);
  }

  /// Set the timeout for bid requests in milliseconds.
  ///
  /// If the Prebid Server does not respond within [timeout] ms,
  /// the bid request fails and the ad's listener reports `onAdFailed`.
  ///
  /// Default value is determined by the native SDK.
  static Future<void> setTimeoutMillis(int timeout) async {
    await api.setTimeoutMillis(timeout);
  }

  /// Enable or disable sharing the device's geo location in bid requests.
  ///
  /// When enabled, the SDK includes `device.geo` fields (latitude, longitude)
  /// in the OpenRTB request, which can improve bid rates.
  static Future<void> setShareGeoLocation(bool share) async {
    await api.setShareGeoLocation(share);
  }

  /// Enable or disable PBS debug mode.
  ///
  /// When enabled, the SDK adds `"test": 1` to outgoing bid requests,
  /// which tells the Prebid Server to return test bids (useful for
  /// development and QA).
  static Future<void> setPbsDebug(bool enabled) async {
    await api.setPbsDebug(enabled);
  }

  /// Set custom HTTP headers to include in every bid request.
  ///
  /// Use this for authentication tokens, custom tracking headers,
  /// or server-specific configuration.
  static Future<void> setCustomHeaders(Map<String, String> headers) async {
    await api.setCustomHeaders(headers);
  }

  /// Set a stored auction response ID for deterministic testing.
  ///
  /// When set, the Prebid Server returns a pre-configured response
  /// instead of running a live auction. Useful for QA and automated testing.
  ///
  /// Call [clearStoredAuctionResponse] to remove it.
  static Future<void> setStoredAuctionResponse(String response) async {
    await api.setStoredAuctionResponse(response);
  }

  /// Remove any previously set stored auction response.
  ///
  /// After calling this, subsequent bid requests will go through
  /// the normal live auction flow.
  static Future<void> clearStoredAuctionResponse() async {
    await api.clearStoredAuctionResponse();
  }

  /// Add a stored bid response for a specific bidder.
  ///
  /// - [bidder] — The bidder name (e.g., `"appnexus"`).
  /// - [responseId] — The stored response ID configured on Prebid Server.
  static Future<void> addStoredBidResponse(
    String bidder,
    String responseId,
  ) async {
    await api.addStoredBidResponse(bidder, responseId);
  }

  /// Remove all stored bid responses.
  static Future<void> clearStoredBidResponses() async {
    await api.clearStoredBidResponses();
  }

  /// Set the SDK log verbosity level.
  ///
  /// See [PrebidLogLevel] for available levels.
  /// The default level is platform-specific.
  static Future<void> setLogLevel(PrebidLogLevel level) async {
    await api.setLogLevel(level.index);
  }

  /// Set the creative factory timeout for banner ads in milliseconds.
  ///
  /// This controls how long the SDK waits for an HTML creative to
  /// load before considering it failed.
  static Future<void> setCreativeFactoryTimeout(int timeout) async {
    await api.setCreativeFactoryTimeout(timeout);
  }

  /// Set the creative factory timeout for pre-render video content in milliseconds.
  ///
  /// This controls how long the SDK waits for a video creative
  /// to pre-render before considering it failed.
  static Future<void> setCreativeFactoryTimeoutPreRenderContent(
    int timeout,
  ) async {
    await api.setCreativeFactoryTimeoutPreRenderContent(timeout);
  }

  /// The creative factory timeout for banner ads in milliseconds (see
  /// [setCreativeFactoryTimeout]). Default 6000.
  ///
  /// Prebid Server can override it per account (the `prebidmobilesdk`
  /// passthrough in a bid response), so it may change after an auction.
  static Future<int> getCreativeFactoryTimeout() async {
    return api.getCreativeFactoryTimeout();
  }

  /// The creative factory timeout for pre-rendered (video and interstitial)
  /// content in milliseconds (see
  /// [setCreativeFactoryTimeoutPreRenderContent]). Default 30000.
  ///
  /// Prebid Server can override it per account, like
  /// [getCreativeFactoryTimeout].
  static Future<int> getCreativeFactoryTimeoutPreRenderContent() async {
    return api.getCreativeFactoryTimeoutPreRenderContent();
  }

  /// Switches the Prebid Server account used by the next auctions, without
  /// calling [initializeSdk] again (which also sets it).
  static Future<void> setPrebidServerAccountId(String accountId) async {
    await api.setPrebidServerAccountId(accountId);
  }

  /// The current Prebid Server account ID (empty before one is set).
  static Future<String> getPrebidServerAccountId() async {
    return api.getPrebidServerAccountId();
  }

  /// Switches the Prebid Server auction endpoint used by the next auctions,
  /// without calling [initializeSdk] again (which also sets it, and runs the
  /// server status check this skips).
  ///
  /// iOS: throws a `PlatformException` for a malformed URL, and a
  /// `nonTrackingUrl` given to [initializeSdk] stays in effect for users who
  /// haven't authorized tracking.
  static Future<void> setPrebidServerUrl(String url) async {
    await api.setPrebidServerUrl(url);
  }

  /// The Prebid Server auction endpoint, or `null` before one is set.
  ///
  /// iOS: the URL auctions use for this user, which is the `nonTrackingUrl`
  /// given to [initializeSdk] when tracking isn't authorized.
  static Future<String?> getPrebidServerUrl() async {
    return api.getPrebidServerUrl();
  }

  /// Asks Prebid Server to cache bids for Rendering API ad units too
  /// (`ext.prebid.cache`), so their impressions can be reported through a
  /// legacy (Prebid Cache based) analytics setup. Default `false`.
  ///
  /// iOS: creating an Original API ad unit turns it on, since Prebid iOS
  /// requests caching for the Original API through this flag.
  static Future<void> setUseCacheForReportingWithRenderingApi(bool use) async {
    await api.setUseCacheForReportingWithRenderingApi(use);
  }

  /// Whether bids are cached for Rendering API reporting (see
  /// [setUseCacheForReportingWithRenderingApi]).
  static Future<bool> getUseCacheForReportingWithRenderingApi() async {
    return api.getUseCacheForReportingWithRenderingApi();
  }

  /// Override the default Prebid Server status endpoint URL.
  ///
  /// The SDK calls this endpoint during initialization to verify
  /// the server is reachable and configured correctly.
  static Future<void> setCustomStatusEndpoint(String endpoint) async {
    await api.setCustomStatusEndpoint(endpoint);
  }

  /// Assign sequential IDs (1, 2, …) to native request assets.
  ///
  /// Required when the native creative refers to assets by ID — Prebid Server
  /// drops a bid whose response assets don't match an ID in the request.
  /// Default `false`.
  static Future<void> setShouldAssignNativeAssetId(bool assign) async {
    await api.setShouldAssignNativeAssetId(assign);
  }

  /// Drop bids whose Prebid Cache entry failed and promote the next cached
  /// bid (Prebid 3.4). When no cached bid remains the result code is
  /// `prebidDemandNoCachedBids`. Applies to the Original API. Default `false`.
  static Future<void> setFilterOutUncachedBids(bool filter) async {
    await api.setFilterOutUncachedBids(filter);
  }

  /// Where external user IDs are sent: `user.eids` (OpenRTB 2.6),
  /// `user.ext.eids` (2.5) or both (default). Prebid 3.4.
  static Future<void> setEidsPlacement(PrebidEidsPlacement placement) async {
    await api.setEidsPlacement(placement.name);
  }

  /// Ask Prebid Server to include `hb_*` winner keywords
  /// (`ext.prebid.targeting.includewinners`).
  static Future<void> setIncludeWinners(bool include) async {
    await api.setIncludeWinners(include);
  }

  /// Ask Prebid Server to include per-bidder `hb_*_<bidder>` keywords
  /// (`ext.prebid.targeting.includebidderkeys`).
  static Future<void> setIncludeBidderKeys(bool include) async {
    await api.setIncludeBidderKeys(include);
  }

  /// Sets the stored auction-settings id (`ext.prebid.storedrequest.id` at
  /// the request level). `null` clears it.
  static Future<void> setAuctionSettingsId(String? settingsId) async {
    await api.setAuctionSettingsId(settingsId);
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
    await api.setSendSharedId(send);
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
    await api.resetSharedId();
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
            ext: u.ext?.map(MapEntry.new),
            inserter: u.inserter,
            matcher: u.matcher,
            mm: u.mm,
          ),
        )
        .toList();
    await api.setExternalUserIds(data);
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
    await api.clearExternalUserIds();
  }

  // ---------------------------------------------------------------------------
  // SDK Version
  // ---------------------------------------------------------------------------

  /// Get the native Prebid Mobile SDK version string.
  ///
  /// The bid request timeout in milliseconds ([setTimeoutMillis]).
  static Future<int> getTimeoutMillis() => api.getTimeoutMillis();

  /// Whether Prebid Server debug is on ([setPbsDebug]).
  static Future<bool> getPbsDebug() => api.getPbsDebug();

  /// Whether the device location is shared ([setShareGeoLocation]).
  static Future<bool> getShareGeoLocation() => api.getShareGeoLocation();

  /// The custom HTTP headers sent to Prebid Server ([setCustomHeaders]).
  static Future<Map<String, String>> getCustomHeaders() =>
      api.getCustomHeaders();

  /// The stored auction response id, or null ([setStoredAuctionResponse]).
  static Future<String?> getStoredAuctionResponse() =>
      api.getStoredAuctionResponse();

  /// The stored bid responses, bidder → response id
  /// ([addStoredBidResponse]).
  static Future<Map<String, String>> getStoredBidResponses() =>
      api.getStoredBidResponses();

  /// The custom status endpoint, or null ([setCustomStatusEndpoint]).
  static Future<String?> getCustomStatusEndpoint() =>
      api.getCustomStatusEndpoint();

  /// Whether native asset ids are assigned ([setShouldAssignNativeAssetId]).
  static Future<bool> getShouldAssignNativeAssetId() =>
      api.getShouldAssignNativeAssetId();

  /// Whether uncached bids are filtered out ([setFilterOutUncachedBids]).
  static Future<bool> getFilterOutUncachedBids() =>
      api.getFilterOutUncachedBids();

  /// Where external user IDs are sent ([setEidsPlacement]).
  static Future<PrebidEidsPlacement> getEidsPlacement() async {
    final name = await api.getEidsPlacement();
    return PrebidEidsPlacement.values.firstWhere(
      (p) => p.name == name,
      orElse: () => PrebidEidsPlacement.compatible,
    );
  }

  /// Whether `ext.prebid.targeting.includewinners` is sent
  /// ([setIncludeWinners]).
  static Future<bool> getIncludeWinners() => api.getIncludeWinners();

  /// Whether `ext.prebid.targeting.includebidderkeys` is sent
  /// ([setIncludeBidderKeys]).
  static Future<bool> getIncludeBidderKeys() => api.getIncludeBidderKeys();

  /// The auction settings id, or null ([setAuctionSettingsId]).
  static Future<String?> getAuctionSettingsId() => api.getAuctionSettingsId();

  /// Whether the status check is skipped ([setDisableStatusCheck]).
  static Future<bool> getDisableStatusCheck() => api.getDisableStatusCheck();

  /// Returns the version of the underlying Android or iOS Prebid SDK.
  static Future<String> getSdkVersion() async {
    return api.getSdkVersion();
  }

  /// Get the version of the Open Measurement SDK bundled with the native
  /// Prebid SDK (used for viewability measurement), e.g. `1.4.1`.
  static Future<String> getOmsdkVersion() async {
    return api.getOmsdkVersion();
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

/// The host API the package's own code uses: [PrebidMobile.api], which tests
/// swap. Not exported.
PrebidMobileHostApi prebidMobileHostApi() => PrebidMobile.api;
