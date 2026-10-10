import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/prebid_api.g.dart',
    dartPackageName: 'prebid_mobile_sdk',
    kotlinOut:
        'android/src/main/kotlin/io/github/thanhhaidev/prebid_mobile_sdk/PrebidApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'io.github.thanhhaidev.prebid_mobile_sdk',
    ),
    swiftOut:
        'ios/prebid_mobile_sdk/Sources/prebid_mobile_sdk/PrebidApi.g.swift',
  ),
)
// =============================================================================
// Data Classes
// =============================================================================
/// Result of SDK initialization.
class InitializationResult {
  InitializationResult({required this.status, this.error});
  final String status;
  final String? error;
}

/// Reward data from a rewarded ad.
class RewardData {
  RewardData({this.type, this.count, this.ext});
  final String? type;
  final int? count;
  final Map<String?, Object?>? ext;
}

/// Ad event sent from native to Flutter.
class AdEvent {
  AdEvent({
    required this.adId,
    required this.eventName,
    this.error,
    this.reward,
    this.nativeAd,
  });
  final int adId;
  final String eventName;
  final String? error;
  final RewardData? reward;
  final NativeAdData? nativeAd;
}

/// Configuration for a native asset in a request.
class NativeAssetConfig {
  NativeAssetConfig({
    required this.assetType,
    this.required_ = false,
    this.titleLength,
    this.imageType,
    this.imageWidth,
    this.imageHeight,
    this.imageWidthMin,
    this.imageHeightMin,
    this.dataType,
    this.dataLength,
    this.imageMimes,
    this.ext,
    this.assetExt,
  });

  /// "title", "image", or "data"
  final String assetType;
  final bool required_;
  final int? titleLength;
  final int? imageType;
  final int? imageWidth;
  final int? imageHeight;
  final int? imageWidthMin;
  final int? imageHeightMin;
  final int? dataType;
  final int? dataLength;

  /// Image MIME types the app accepts (image assets only).
  final List<String?>? imageMimes;

  /// JSON object for the `ext` of the title, img or data object.
  final String? ext;

  /// JSON object for the asset's own `ext` (Android only).
  final String? assetExt;
}

/// Configuration for a native event tracker.
class NativeEventTrackerConfig {
  NativeEventTrackerConfig({
    required this.eventType,
    required this.methods,
    this.ext,
  });
  final int eventType;
  final List<int> methods;

  /// JSON object for the tracker's `ext` (Android only).
  final String? ext;
}

/// Full configuration for a native ad request.
class NativeAdRequestConfig {
  NativeAdRequestConfig({
    required this.configId,
    this.assets,
    this.eventTrackers,
    this.context,
    this.contextSubType,
    this.placementType,
    this.placementCount,
    this.pbAdSlot,
    this.gpid,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.sequence,
    this.assetUrlSupport,
    this.dUrlSupport,
    this.privacy,
    this.ext,
  });
  final String configId;
  final List<NativeAssetConfig?>? assets;
  final List<NativeEventTrackerConfig?>? eventTrackers;
  final int? context;
  final int? contextSubType;
  final int? placementType;
  final int? placementCount;
  final String? pbAdSlot;
  final String? gpid;
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only.
  final String? globalOrtbConfig;

  /// Native request `seq`, `aurlsupport`, `durlsupport` and `privacy`.
  final int? sequence;
  final bool? assetUrlSupport;
  final bool? dUrlSupport;
  final bool? privacy;

  /// Native request `ext`, as JSON.
  final String? ext;
}

/// Native ad response data sent back to Flutter.
class NativeAdData {
  NativeAdData({
    this.title,
    this.text,
    this.iconUrl,
    this.imageUrl,
    this.sponsoredBy,
    this.callToAction,
    this.clickUrl,
    this.privacyUrl,
    this.titles,
    this.images,
    this.dataAssets,
  });
  final String? title;
  final String? text;
  final String? iconUrl;
  final String? imageUrl;
  final String? sponsoredBy;
  final String? callToAction;
  final String? clickUrl;

  /// AdChoices / privacy link (native `privacy`).
  final String? privacyUrl;

  /// Every title, image and data asset of the response.
  final List<String?>? titles;
  final List<NativeAdImageData?>? images;
  final List<NativeAdDataAssetData?>? dataAssets;
}

/// A native response image asset (type: 1=icon, 3=main).
class NativeAdImageData {
  NativeAdImageData({required this.type, this.url, this.width, this.height});
  final int type;
  final String? url;

  /// iOS only: the image size the bid declares (Prebid Android drops it).
  final int? width;
  final int? height;
}

/// A native response data asset (OpenRTB native data asset type).
class NativeAdDataAssetData {
  NativeAdDataAssetData({required this.type, this.value});
  final int type;
  final String? value;
}

/// One `uids` entry of an [ExternalUserIdData].
class UserUniqueIdData {
  UserUniqueIdData({required this.id, required this.atype, this.ext});

  /// The user ID value.
  final String id;

  /// ID type per OpenRTB: 1=device, 2=person, 3=user, etc.
  final int atype;

  /// Optional vendor-specific extensions.
  final Map<String?, Object?>? ext;
}

/// External user ID for third-party identity modules (UID2, SharedID, etc.):
/// one `user.eids` entry.
class ExternalUserIdData {
  ExternalUserIdData({
    required this.source,
    required this.uids,
    this.ext,
    this.inserter,
    this.matcher,
    this.mm,
  });

  /// ID source (e.g., "uidapi.com", "sharedid.org").
  final String source;

  /// The IDs from this source.
  final List<UserUniqueIdData?> uids;

  /// The eid-level `ext`.
  final Map<String?, Object?>? ext;

  /// OpenRTB 2.6 EID `inserter` (who inserted the ID).
  final String? inserter;

  /// OpenRTB 2.6 EID `matcher` (who matched the ID).
  final String? matcher;

  /// OpenRTB 2.6 EID `mm` (match method).
  final int? mm;
}

/// Video parameters configuration for OpenRTB video objects.
class VideoParametersConfig {
  VideoParametersConfig({
    required this.mimes,
    this.protocols,
    this.playbackMethods,
    this.placement,
    this.maxDuration,
    this.minDuration,
    this.api,
    this.plcmt,
    this.startDelay,
    this.linearity,
    this.skippable,
    this.battr,
    this.minBitrate,
    this.maxBitrate,
    this.width,
    this.height,
  });

  /// Supported content MIME types (e.g., ["video/mp4"]).
  final List<String> mimes;

  /// Supported VAST protocol IDs.
  final List<int?>? protocols;

  /// Playback method IDs.
  final List<int?>? playbackMethods;

  /// Placement type (1=in-stream, 2=in-banner, 3=in-article, 4=in-feed).
  final int? placement;

  /// Maximum video duration in seconds.
  final int? maxDuration;

  /// Minimum video duration in seconds.
  final int? minDuration;

  /// Supported API frameworks (1=VPAID 1.0, 2=VPAID 2.0, 3=MRAID-1, etc.).
  final List<int?>? api;

  /// OpenRTB 2.6 placement subtype (`plcmt`): 1=instream, 2=accompanying
  /// content, 3=interstitial, 4=no content / standalone.
  final int? plcmt;

  /// Start delay in seconds, or 0=pre-roll, -1=generic mid-roll,
  /// -2=generic post-roll.
  final int? startDelay;

  /// 1=linear (in-stream), 2=non-linear (overlay).
  final int? linearity;
  final bool? skippable;

  /// Blocked creative attributes (OpenRTB 5.3).
  final List<int?>? battr;

  /// Bitrate bounds in Kbps.
  final int? minBitrate;
  final int? maxBitrate;

  /// Video player size (`video.w` / `video.h`).
  final int? width;
  final int? height;
}

/// Fullscreen (interstitial / rewarded) rendering controls.
class FullscreenControlsConfig {
  FullscreenControlsConfig({
    this.closeButtonArea,
    this.closeButtonPosition,
    this.skipButtonArea,
    this.skipButtonPosition,
    this.skipDelay,
    this.isMuted,
    this.isSoundButtonVisible,
    this.isAutoCloseOnCompletionEnabled,
    this.minWidthPercentage,
    this.minHeightPercentage,
    this.supportSKOverlay,
  });

  /// Close button size as a fraction of the screen (0..1).
  final double? closeButtonArea;

  /// "topLeft" or "topRight".
  final String? closeButtonPosition;

  /// Skip button size as a fraction of the screen (0..1).
  final double? skipButtonArea;

  /// "topLeft" or "topRight".
  final String? skipButtonPosition;

  /// Seconds before the skip button appears.
  final int? skipDelay;
  final bool? isMuted;
  final bool? isSoundButtonVisible;

  /// iOS only.
  final bool? isAutoCloseOnCompletionEnabled;

  /// Minimum creative size in percent of the screen (interstitial only).
  final int? minWidthPercentage;
  final int? minHeightPercentage;

  /// iOS only: show an SKOverlay for SKAdNetwork ads.
  final bool? supportSKOverlay;
}

// =============================================================================
// Host APIs (Dart → Native)
// =============================================================================

/// Core SDK initialization and configuration.
@HostApi()
abstract class PrebidMobileHostApi {
  @asyncCallback
  InitializationResult initializeSdk(
    String prebidServerUrl,
    String accountId,
    String? nonTrackingUrl,
  );

  void setTimeoutMillis(int timeoutMillis);
  void setShareGeoLocation(bool share);
  void setPbsDebug(bool enabled);
  void setCustomHeaders(Map<String, String> headers);
  void setStoredAuctionResponse(String response);
  void clearStoredAuctionResponse();
  void addStoredBidResponse(String bidder, String responseId);
  void clearStoredBidResponses();
  void setLogLevel(int level);
  void setCreativeFactoryTimeout(int timeout);
  void setCreativeFactoryTimeoutPreRenderContent(int timeout);

  /// Creative factory timeouts in milliseconds (iOS stores seconds).
  int getCreativeFactoryTimeout();
  int getCreativeFactoryTimeoutPreRenderContent();

  /// Prebid Server account, switchable without re-initializing.
  void setPrebidServerAccountId(String accountId);
  String getPrebidServerAccountId();

  /// Prebid Server auction endpoint, switchable without re-initializing.
  /// The getter returns null when no endpoint is set.
  void setPrebidServerUrl(String url);
  String? getPrebidServerUrl();

  void setUseCacheForReportingWithRenderingApi(bool use);
  bool getUseCacheForReportingWithRenderingApi();
  void setCustomStatusEndpoint(String endpoint);
  void setShouldAssignNativeAssetId(bool assign);
  void setFilterOutUncachedBids(bool filter);
  void setEidsPlacement(String placement);
  void setIncludeWinners(bool include);
  void setIncludeBidderKeys(bool include);
  void setAuctionSettingsId(String? settingsId);

  /// Skip the Prebid Server status request during initialization.
  void setDisableStatusCheck(bool disable);

  /// Enables / disables forwarding bid request + response pairs to
  /// [PrebidEventFlutterApi.onBidResponse] (`PrebidEventDelegate`).
  void setEventDelegateEnabled(bool enabled);

  /// Routes Prebid's log messages to [PrebidEventFlutterApi.onLog] instead of
  /// the console (Prebid's custom logger), or restores the console.
  void setLogListenerEnabled(bool enabled);

  /// iOS only: Prebid's own location updates (`locationUpdatesEnabled`);
  /// the getter returns null on Android.
  void setLocationUpdatesEnabled(bool enabled);
  bool? getLocationUpdatesEnabled();

  // SharedID
  void setSendSharedId(bool send);
  ExternalUserIdData? getSharedId();
  void resetSharedId();

  // External User IDs
  void setExternalUserIds(List<ExternalUserIdData> userIds);
  List<ExternalUserIdData> getExternalUserIds();
  void clearExternalUserIds();

  // Current values of the settings above.
  int getTimeoutMillis();
  bool getPbsDebug();
  bool getShareGeoLocation();
  Map<String, String> getCustomHeaders();
  String? getStoredAuctionResponse();

  /// Bidder → stored response id.
  Map<String, String> getStoredBidResponses();
  String? getCustomStatusEndpoint();
  bool getShouldAssignNativeAssetId();
  bool getFilterOutUncachedBids();
  String getEidsPlacement();
  bool getIncludeWinners();
  bool getIncludeBidderKeys();
  String? getAuctionSettingsId();
  bool getDisableStatusCheck();

  // SDK Version
  String getSdkVersion();

  /// Version of the Open Measurement SDK bundled with Prebid.
  String getOmsdkVersion();

  /// Destroys every ad this engine holds natively (fullscreen, native,
  /// multiformat, in-stream). Called once by a new Dart isolate before its
  /// first ad: after a hot restart the previous isolate's ads would otherwise
  /// keep running (auto-refresh auctions) under ad ids the new one reuses.
  void releaseAds();
}

/// Targeting and privacy settings.
@HostApi()
abstract class TargetingHostApi {
  // COPPA
  void setSubjectToCOPPA(bool? value);
  bool? getSubjectToCOPPA();

  // GDPR
  void setSubjectToGDPR(bool? value);
  bool? getSubjectToGDPR();
  void setGDPRConsentString(String? value);
  String? getGDPRConsentString();

  // TCFv2
  void setPurposeConsents(String? value);
  String? getPurposeConsents();

  /// Consent for one TCF purpose (0-based index), from the CMP's purpose
  /// consents.
  bool? getPurposeConsent(int index);
  bool? getDeviceAccessConsent();

  /// Whether the consent signals allow reading device data (TCF purpose 1).
  bool isAllowedAccessDeviceData();

  // US Privacy / CCPA
  void setUSPrivacyString(String? value);
  String? getUSPrivacyString();

  // User Keywords
  void addUserKeyword(String keyword);
  void addUserKeywords(List<String> keywords);
  void removeUserKeyword(String keyword);
  void clearUserKeywords();
  List<String> getUserKeywords();

  // App Keywords
  void addAppKeyword(String keyword);
  void addAppKeywords(List<String> keywords);
  void removeAppKeyword(String keyword);
  void clearAppKeywords();
  List<String> getAppKeywords();

  // App Ext Data
  void addAppExtData(String key, String value);
  void updateAppExtData(String key, List<String> value);
  void removeAppExtData(String key);
  void clearAppExtData();

  // User Ext Data (user.ext.data)
  void addUserExtData(String key, String value);
  void updateUserExtData(String key, List<String> value);
  void removeUserExtData(String key);
  void clearUserExtData();

  // Access Control List
  void addBidderToAccessControlList(String bidderName);
  void removeBidderFromAccessControlList(String bidderName);
  void clearAccessControlList();

  // ORTB Config
  void setGlobalOrtbConfig(String? ortbConfig);
  String? getGlobalOrtbConfig();

  // App Info
  void setPublisherName(String? name);
  void setStoreUrl(String? url);
  void setDomain(String? domain);

  /// Overrides `app.name`; null restores the app's own name.
  void setAppName(String? name);

  // OMID partner
  /// iOS only: SKAdNetwork `sourceapp` (the app's iTunes ID) and the
  /// `app.storeurl` iTunes ID.
  void setSourceApp(String? sourceApp);
  void setItunesId(String? itunesId);

  /// Android only: overrides `app.bundle`; null restores the app's own.
  void setBundleName(String? bundleName);
  String? getBundleName();

  void setOmidPartnerName(String? name);
  void setOmidPartnerVersion(String? version);

  // Location
  void setUserLatLng(double latitude, double longitude);
  void clearUserLatLng();
  void setLocationPrecision(int? precision);

  // Current values of the settings above.
  Map<String, List<String>> getAppExtData();
  List<String> getAccessControlList();
  String? getPublisherName();
  String? getStoreUrl();
  String? getDomain();
  String? getOmidPartnerName();
  String? getOmidPartnerVersion();
  bool getSendSharedId();

  /// [latitude, longitude], or null when not set.
  List<double>? getUserLatLng();
  int? getLocationPrecision();

  /// iOS only: the SKAdNetwork `sourceapp` and the iTunes ID (null on
  /// Android).
  String? getSourceApp();
  String? getItunesId();
}

/// Interstitial ad operations (Dart → Native).
@HostApi()
abstract class InterstitialAdHostApi {
  void loadAd(
    int adId,
    String configId,
    List<String>? adFormats,
    VideoParametersConfig? videoConfig,
    String? impOrtbConfig,
    String? globalOrtbConfig,
    FullscreenControlsConfig? controls,
    String? pbAdSlot,
  );
  void show(int adId);
  void destroy(int adId);
}

/// Rewarded ad operations (Dart → Native).
@HostApi()
abstract class RewardedAdHostApi {
  void loadAd(
    int adId,
    String configId,
    List<String>? adFormats,
    VideoParametersConfig? videoConfig,
    String? impOrtbConfig,
    String? globalOrtbConfig,
    FullscreenControlsConfig? controls,
    String? pbAdSlot,
  );
  void show(int adId);
  void destroy(int adId);
}

/// Native ad operations (Dart → Native).
@HostApi()
abstract class NativeAdHostApi {
  void loadAd(int adId, NativeAdRequestConfig config);

  /// Loads the native ad a Prebid cache id points to (an Original API native
  /// win); the result arrives like [loadAd]'s.
  void loadFromCacheId(int adId, String cacheId);

  /// Reports a click on the ad's tracking view (a custom Flutter layout).
  /// Returns false when the ad has no tracking view on screen.
  bool performClick(int adId);
  void destroy(int adId);
}

/// Configuration for a multiformat ad request.
class MultiformatAdRequestConfig {
  MultiformatAdRequestConfig({
    required this.configId,
    this.bannerSizes,
    this.videoConfig,
    this.nativeConfig,
    this.isInterstitial = false,
    this.isRewarded = false,
    this.gpid,
    this.adPosition,
    this.trackInterstitialImpression = false,
    this.bannerApi,
    this.interstitialMinWidthPercentage,
    this.interstitialMinHeightPercentage,
    this.supportSKOverlay = false,
    this.pbAdSlot,
    this.impOrtbConfig,
    this.globalOrtbConfig,
  });
  final String configId;
  final String? gpid;

  /// iOS only (Prebid Android's PrebidAdUnit has no setters for them):
  /// `imp.ext.data.pbadslot`, impression-level and per-unit request-level
  /// OpenRTB JSON.
  final String? pbAdSlot;
  final String? impOrtbConfig;
  final String? globalOrtbConfig;

  /// Banner API frameworks (OpenRTB `banner.api`).
  final List<int?>? bannerApi;

  /// Minimum interstitial creative size, in percent of the screen.
  final int? interstitialMinWidthPercentage;
  final int? interstitialMinHeightPercentage;

  /// iOS only: SKOverlay for SKAdNetwork interstitial wins.
  final bool supportSKOverlay;

  /// OpenRTB `pos` (PrebidAdPosition value).
  final int? adPosition;

  /// Track the Prebid impression when the ad server's interstitial shows
  /// the Prebid creative.
  final bool trackInterstitialImpression;

  /// Banner sizes as [width, height, width, height, ...]
  final List<int?>? bannerSizes;
  final VideoParametersConfig? videoConfig;
  final NativeAdRequestConfig? nativeConfig;
  final bool isInterstitial;
  final bool isRewarded;
}

/// Result of a multiformat bid request.
class MultiformatBidResult {
  MultiformatBidResult({
    required this.resultCode,
    this.winningFormat,
    this.targetingKeywords,
    this.nativeAdCacheId,
    this.exp,
    this.topBidFiltered,
    this.events,
  });
  final String resultCode;

  /// The winning bid's event URLs (`win`, `imp`), when the server sends them.
  final Map<String?, String?>? events;

  /// Winning bid expiration in seconds (`bid.exp`), if provided.
  final double? exp;

  /// True when the top bid was dropped for a failed Prebid Cache entry and the
  /// next cached bid was promoted (`filterOutUncachedBids`).
  final bool? topBidFiltered;

  /// "banner", "video", or "native"
  final String? winningFormat;
  final Map<String?, String?>? targetingKeywords;
  final String? nativeAdCacheId;
}

/// Multiformat ad operations (Dart → Native).
@HostApi()
abstract class MultiformatAdHostApi {
  @asyncCallback
  MultiformatBidResult fetchDemand(int adId, MultiformatAdRequestConfig config);

  /// Auto-refresh of the demand; refreshed results arrive through
  /// [MultiformatFlutterApi.onDemandRefreshed].
  void setAutoRefreshInterval(int adId, int seconds);
  void stopAutoRefresh(int adId);
  void resumeAutoRefresh(int adId);

  /// Starts Prebid's impression tracker on the ad server's banner view (the
  /// only Google Mobile Ads banner on screen). Returns false if there is not
  /// exactly one.
  bool activateBannerImpressionTracker(int adId);

  /// Size of the Prebid creative inside the ad server's banner view (the only
  /// Google Mobile Ads banner on screen), as [width, height]; null when it
  /// can't be found.
  @asyncCallback
  List<int>? findPrebidCreativeSize(int adId);

  /// iOS only: SKAdNetwork StoreKit flows and SKOverlay for the Original API.
  /// Return false (or do nothing) on Android and when there is no view.
  bool activateBannerSKAdNetwork(int adId);
  void activateInterstitialSKAdNetwork(int adId);
  void activateSKOverlay(int adId);
  void dismissSKOverlay(int adId);
  void destroy(int adId);
}

/// Original API events (Native → Dart).
@FlutterApi()
abstract class MultiformatFlutterApi {
  @asyncCallback
  void onDemandRefreshed(int adId, MultiformatBidResult result);
}

/// Configuration for an in-stream video ad request.
class InstreamVideoAdRequestConfig {
  InstreamVideoAdRequestConfig({
    required this.configId,
    required this.width,
    required this.height,
    this.videoConfig,
    this.gpid,
    this.pbAdSlot,
    this.impOrtbConfig,
    this.globalOrtbConfig,
  });
  final String configId;
  final int width;
  final int height;
  final VideoParametersConfig? videoConfig;
  final String? gpid;
  final String? pbAdSlot;
  final String? impOrtbConfig;
  final String? globalOrtbConfig;
}

/// In-stream video ad operations (Dart → Native).
@HostApi()
abstract class InstreamVideoAdHostApi {
  @asyncCallback
  MultiformatBidResult fetchDemand(
    int adId,
    InstreamVideoAdRequestConfig config,
  );
  void destroy(int adId);

  /// The Google Ad Manager VAST tag URL for an IMA player, with the bid's
  /// targeting keywords; sizes are [width, height, ...]. Throws for a size
  /// iOS doesn't support (400x300, 640x480 and 320x480 only).
  String generateInstreamUriForGam(
    String adUnitId,
    List<int> sizes,
    Map<String, String> keywords,
  );
}

// =============================================================================
// Flutter APIs (Native → Dart)
// =============================================================================

/// Callbacks for ad events from native to Flutter.
@FlutterApi()
abstract class AdFlutterApi {
  @asyncCallback
  void onAdEvent(AdEvent event);
}

/// Bid request / response pairs from `PrebidEventDelegate` (native → Flutter).
@FlutterApi()
abstract class PrebidEventFlutterApi {
  @asyncCallback
  void onBidResponse(String? request, String? response);

  /// A Prebid log message; level is a PrebidLogLevel index.
  @asyncCallback
  void onLog(int level, String message);
}
