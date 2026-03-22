import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/generated/prebid_api.g.dart',
  dartPackageName: 'prebid_mobile_flutter',
  kotlinOut:
      'android/src/main/kotlin/com/prebid/prebid_mobile_flutter/PrebidApi.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.prebid.prebid_mobile_flutter'),
  swiftOut: 'ios/Classes/PrebidApi.g.swift',
))

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
  AdEvent({required this.adId, required this.eventName, this.error, this.reward, this.nativeAd});
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
}

/// Configuration for a native event tracker.
class NativeEventTrackerConfig {
  NativeEventTrackerConfig({required this.eventType, required this.methods});
  final int eventType;
  final List<int> methods;
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
  });
  final String configId;
  final List<NativeAssetConfig?>? assets;
  final List<NativeEventTrackerConfig?>? eventTrackers;
  final int? context;
  final int? contextSubType;
  final int? placementType;
  final int? placementCount;
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
  });
  final String? title;
  final String? text;
  final String? iconUrl;
  final String? imageUrl;
  final String? sponsoredBy;
  final String? callToAction;
  final String? clickUrl;
}

// =============================================================================
// Host APIs (Dart → Native)
// =============================================================================

/// Core SDK initialization and configuration.
@HostApi()
abstract class PrebidMobileHostApi {
  @async
  InitializationResult initializeSdk(
      String prebidServerUrl, String accountId);

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
  void setCustomStatusEndpoint(String endpoint);
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
  bool? getDeviceAccessConsent();

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

  // App Ext Data
  void addAppExtData(String key, String value);
  void updateAppExtData(String key, List<String> value);
  void removeAppExtData(String key);
  void clearAppExtData();

  // Access Control List
  void addBidderToAccessControlList(String bidderName);
  void removeBidderFromAccessControlList(String bidderName);
  void clearAccessControlList();

  // ORTB Config
  void setGlobalOrtbConfig(String? ortbConfig);
  String? getGlobalOrtbConfig();

  // App Info
  void setContentUrl(String? url);
  void setPublisherName(String? name);
  void setStoreUrl(String? url);
  void setDomain(String? domain);
}

/// Interstitial ad operations (Dart → Native).
@HostApi()
abstract class InterstitialAdHostApi {
  void loadAd(int adId, String configId, List<String>? adFormats);
  void show(int adId);
  void destroy(int adId);
}

/// Rewarded ad operations (Dart → Native).
@HostApi()
abstract class RewardedAdHostApi {
  void loadAd(int adId, String configId);
  void show(int adId);
  void destroy(int adId);
}

/// Native ad operations (Dart → Native).
@HostApi()
abstract class NativeAdHostApi {
  void loadAd(int adId, NativeAdRequestConfig config);
  void trackImpression(int adId);
  void trackClick(int adId);
  void destroy(int adId);
}

/// Configuration for a multiformat ad request.
class MultiformatAdRequestConfig {
  MultiformatAdRequestConfig({
    required this.configId,
    this.bannerSizes,
    this.includeVideo = false,
    this.nativeConfig,
    this.isInterstitial = false,
    this.isRewarded = false,
  });
  final String configId;
  /// Banner sizes as [width, height, width, height, ...]
  final List<int?>? bannerSizes;
  final bool includeVideo;
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
  });
  final String resultCode;
  /// "banner", "video", or "native"
  final String? winningFormat;
  final Map<String?, String?>? targetingKeywords;
  final String? nativeAdCacheId;
}

/// Multiformat ad operations (Dart → Native).
@HostApi()
abstract class MultiformatAdHostApi {
  @async
  MultiformatBidResult fetchDemand(int adId, MultiformatAdRequestConfig config);
  void destroy(int adId);
}

/// Configuration for an in-stream video ad request.
class InstreamVideoAdRequestConfig {
  InstreamVideoAdRequestConfig({
    required this.configId,
    required this.width,
    required this.height,
  });
  final String configId;
  final int width;
  final int height;
}

/// In-stream video ad operations (Dart → Native).
@HostApi()
abstract class InstreamVideoAdHostApi {
  @async
  MultiformatBidResult fetchDemand(int adId, InstreamVideoAdRequestConfig config);
  void destroy(int adId);
}

// =============================================================================
// Flutter APIs (Native → Dart)
// =============================================================================

/// Callbacks for ad events from native to Flutter.
@FlutterApi()
abstract class AdFlutterApi {
  void onAdEvent(AdEvent event);
}
