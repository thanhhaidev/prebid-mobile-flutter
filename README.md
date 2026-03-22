# Prebid Mobile Flutter

[![pub package](https://img.shields.io/pub/v/prebid_mobile_flutter.svg)](https://pub.dev/packages/prebid_mobile_flutter)
[![Flutter CI](https://github.com/thanhhaidev/prebid-mobile-flutter/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/thanhhaidev/prebid-mobile-flutter/actions/workflows/flutter_ci.yml)

A comprehensive Flutter plugin wrapping the [Prebid Mobile SDK](https://docs.prebid.org/prebid-mobile/prebid-mobile-getting-started.html) for **Android** and **iOS**.

This plugin focuses on the **Prebid Rendered (In-App Bidding)** approach — the Prebid SDK handles both the auction and rendering directly, with no external ad server required.

---

## Table of Contents

- [Features](#features)
- [Platform Requirements](#platform-requirements)
- [Installation](#installation)
- [Getting Started](#getting-started)
- [API Reference](#api-reference)
  - [PrebidMobile — SDK Configuration](#prebidmobile--sdk-configuration)
  - [PrebidTargeting — Privacy & Targeting](#prebidtargeting--privacy--targeting)
  - [PrebidBannerAd — Banner Ads](#prebidbannerad--banner-ads)
  - [PrebidInterstitialAd — Interstitial Ads](#prebidinterstitialad--interstitial-ads)
  - [PrebidRewardedAd — Rewarded Ads](#prebidrewardedad--rewarded-ads)
  - [PrebidNativeAd — Native Ads](#prebidnativead--native-ads)
  - [PrebidMultiformatAd — Multiformat Ads](#prebidmultiformatad--multiformat-ads)
  - [PrebidInstreamVideoAd — In-Stream Video](#prebidinstreamvideoad--in-stream-video)
  - [VideoParameters — Video Configuration](#videoparameters--video-configuration)
  - [ExternalUserId — Identity Modules](#externaluserid--identity-modules)
  - [Enums](#enums)
  - [Listeners & Callbacks](#listeners--callbacks)
  - [Error Handling](#error-handling)
- [Example App](#example-app)
- [Contributing](#contributing)
- [License](#license)

---

## Features

| Feature | Description |
|---|---|
| **Banner Ads** | Display and video banners via native `PlatformView` widgets with auto-refresh support. |
| **Interstitial Ads** | Fullscreen display and video ads with load/show lifecycle and video parameters. |
| **Rewarded Ads** | Fullscreen ads that grant users a typed reward on completion. |
| **Native Ads** | Fetch raw native assets (Title, Image, Icon, CTA, Sponsored, Description) and render custom Flutter UIs. |
| **Multiformat Ads** | Request banner, video, and native demand on a single ad unit simultaneously. |
| **In-Stream Video** | Fetch VAST video demand for integration with your own player or ad server. |
| **Video Parameters** | Full OpenRTB video configuration — protocols, playback methods, placement, duration limits. |
| **External User IDs** | Third-party identity modules (UID2, SharedID, LiveRamp, etc.) for improved fill rates. |
| **Privacy & Compliance** | GDPR, COPPA, TCFv2, CCPA/US Privacy, and GPP consent support. |
| **First-Party Data** | User/app keywords, user/app ext data, access control list, and global OpenRTB config. |
| **Stored Responses** | Stored auction and bid responses for deterministic testing without live auctions. |

---

## Platform Requirements

| Platform | Minimum Version |
|----------|----------------|
| Flutter  | ≥ 3.41.0       |
| Dart     | ≥ 3.11.0       |
| Android  | API 24 (Android 7.0) |
| iOS      | 13.0           |

**Native SDK versions bundled:**

- **Android:** Prebid Mobile SDK `3.3.0` (Maven)
- **iOS:** PrebidMobile `~> 3.1` (CocoaPods)

---

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  prebid_mobile_flutter: ^0.0.1
```

### iOS

Ensure your `ios/Podfile` specifies `platform :ios, '13.0'`, then run:

```bash
cd ios && pod install
```

### Android

No additional setup needed. The Prebid Mobile Android SDK is included automatically via Maven.

---

## Getting Started

### 1. Initialize the SDK

Call `PrebidMobile.initializeSdk` once at app launch, before loading any ads:

```dart
import 'package:prebid_mobile_flutter/prebid_mobile_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PrebidMobile.initializeSdk(
    prebidServerUrl: 'https://prebid-server-test-j.prebid.org/openrtb2/auction',
    accountId: '0689a263-318d-448b-a3d4-b02e8a709d9d',
    completion: (status, error) {
      if (status == InitializationStatus.succeeded) {
        debugPrint('Prebid SDK initialized successfully');
      } else {
        debugPrint('Prebid SDK init failed: $error');
      }
    },
  );

  runApp(const MyApp());
}
```

### 2. Display a Banner Ad

```dart
PrebidBannerAd(
  configId: 'prebid-demo-banner-320-50',
  width: 320,
  height: 50,
  refreshIntervalSeconds: 30, // Auto-refresh every 30s
  listener: PrebidBannerAdListener(
    onAdLoaded: () => debugPrint('Banner loaded'),
    onAdFailed: (error) => debugPrint('Banner failed: $error'),
    onAdClicked: () => debugPrint('Banner clicked'),
    onAdClosed: () => debugPrint('Banner closed'),
  ),
)
```

### 3. Show an Interstitial Ad

```dart
final interstitial = PrebidInterstitialAd(
  configId: 'prebid-demo-display-interstitial-320-480',
  adFormats: {AdFormat.banner, AdFormat.video},
  videoParameters: const VideoParameters(
    mimes: ['video/mp4'],
    protocols: [VideoProtocol.vast2_0, VideoProtocol.vast3_0],
    playbackMethods: [VideoPlaybackMethod.autoPlaySoundOff],
  ),
  listener: PrebidInterstitialAdListener(
    onAdLoaded: () async => await interstitial.show(),
    onAdDismissed: () async => await interstitial.destroy(),
  ),
);

await interstitial.loadAd();
```

### 4. Show a Rewarded Ad

```dart
final rewarded = PrebidRewardedAd(
  configId: 'prebid-demo-video-rewarded-320-480',
  listener: PrebidRewardedAdListener(
    onAdLoaded: () async => await rewarded.show(),
    onUserEarnedReward: (reward) {
      debugPrint('Earned: ${reward.count}x ${reward.type}');
    },
    onAdDismissed: () async => await rewarded.destroy(),
  ),
);

await rewarded.loadAd();
```

### 5. Set External User IDs

```dart
await PrebidMobile.setExternalUserIds([
  ExternalUserId(source: 'uidapi.com', identifier: 'uid2-abc-123', atype: 3),
  ExternalUserId(source: 'sharedid.org', identifier: 'shared-xyz', atype: 1),
]);
```

### 6. Configure Privacy

```dart
// GDPR
await PrebidTargeting.setSubjectToGDPR(true);
await PrebidTargeting.setGDPRConsentString('BOEFEAyOEFEAyAHABDENAI4AAAB9...');

// CCPA / US Privacy
await PrebidTargeting.setUSPrivacyString('1YNN');

// COPPA
await PrebidTargeting.setSubjectToCOPPA(false);
```

---

## API Reference

### `PrebidMobile` — SDK Configuration

Static class for SDK initialization, global configuration, and identity management.

| Method | Returns | Description |
|---|---|---|
| `initializeSdk({prebidServerUrl, accountId, completion})` | `Future<void>` | Initialize the SDK with your Prebid Server endpoint and account ID. |
| `setTimeoutMillis(int timeout)` | `Future<void>` | Set the bid request timeout in milliseconds. |
| `setShareGeoLocation(bool share)` | `Future<void>` | Enable or disable sharing the device's geo location. |
| `setPbsDebug(bool enabled)` | `Future<void>` | Enable PBS debug mode (`"test": 1` in bid requests). |
| `setLogLevel(PrebidLogLevel level)` | `Future<void>` | Set SDK log verbosity. |
| `setCustomHeaders(Map<String, String> headers)` | `Future<void>` | Set custom HTTP headers for bid requests. |
| `setStoredAuctionResponse(String response)` | `Future<void>` | Set a stored auction response ID for testing. |
| `clearStoredAuctionResponse()` | `Future<void>` | Clear stored auction response. |
| `addStoredBidResponse(String bidder, String responseId)` | `Future<void>` | Add a stored bid response for a specific bidder. |
| `clearStoredBidResponses()` | `Future<void>` | Remove all stored bid responses. |
| `setCreativeFactoryTimeout(int timeout)` | `Future<void>` | Set the HTML creative factory timeout (ms). |
| `setCreativeFactoryTimeoutPreRenderContent(int timeout)` | `Future<void>` | Set the video pre-render creative factory timeout (ms). |
| `setCustomStatusEndpoint(String endpoint)` | `Future<void>` | Override the Prebid Server status endpoint URL. |
| `setExternalUserIds(List<ExternalUserId> userIds)` | `Future<void>` | Set external user IDs for identity modules. |
| `getExternalUserIds()` | `Future<List<ExternalUserId>>` | Get all currently set external user IDs. |
| `clearExternalUserIds()` | `Future<void>` | Clear all external user IDs. |
| `getSdkVersion()` | `Future<String>` | Get the native Prebid SDK version string. |

---

### `PrebidTargeting` — Privacy & Targeting

Static class for managing privacy consent, first-party data, and targeting parameters.

#### Privacy & Consent

| Method | Returns | Description |
|---|---|---|
| `setSubjectToCOPPA(bool? subject)` | `Future<void>` | COPPA flag. Pass `null` to clear. |
| `getSubjectToCOPPA()` | `Future<bool?>` | Get COPPA status. |
| `setSubjectToGDPR(bool? subject)` | `Future<void>` | GDPR flag. Pass `null` to clear. |
| `getSubjectToGDPR()` | `Future<bool?>` | Get GDPR status. |
| `setGDPRConsentString(String? consent)` | `Future<void>` | Set IAB TCF consent string. |
| `getGDPRConsentString()` | `Future<String?>` | Get GDPR consent string. |
| `setPurposeConsents(String? consents)` | `Future<void>` | Set TCFv2 purpose consents (binary string). |
| `getPurposeConsents()` | `Future<String?>` | Get TCFv2 purpose consents. |
| `getDeviceAccessConsent()` | `Future<bool?>` | Get device access consent (TCFv2 Purpose 1). |
| `setUSPrivacyString(String? usPrivacy)` | `Future<void>` | Set IAB US Privacy String for CCPA (`"1YNN"`). |
| `getUSPrivacyString()` | `Future<String?>` | Get current US Privacy String. |

> **Note:** GPP consent signals (`IABGPP_HDR_GppString`, `IABGPP_GppSID`) are automatically read by the native SDKs from SharedPreferences (Android) / UserDefaults (iOS). A CMP SDK will populate these values automatically.

#### User Keywords (`user.keywords`)

| Method | Returns | Description |
|---|---|---|
| `addUserKeyword(String keyword)` | `Future<void>` | Add a single user keyword. |
| `addUserKeywords(Set<String> keywords)` | `Future<void>` | Add multiple user keywords. |
| `removeUserKeyword(String keyword)` | `Future<void>` | Remove a single user keyword. |
| `clearUserKeywords()` | `Future<void>` | Remove all user keywords. |
| `getUserKeywords()` | `Future<List<String>>` | Get all user keywords. |

#### App Keywords (`app.keywords`)

| Method | Returns | Description |
|---|---|---|
| `addAppKeyword(String keyword)` | `Future<void>` | Add a single app keyword. |
| `addAppKeywords(Set<String> keywords)` | `Future<void>` | Add multiple app keywords. |
| `removeAppKeyword(String keyword)` | `Future<void>` | Remove a single app keyword. |
| `clearAppKeywords()` | `Future<void>` | Remove all app keywords. |

#### App Ext Data — First-Party Data (`app.ext.data`)

| Method | Returns | Description |
|---|---|---|
| `addAppExtData({key, value})` | `Future<void>` | Append a value to app ext data for a key. |
| `updateAppExtData({key, value})` | `Future<void>` | Replace all values for a key with a `Set<String>`. |
| `removeAppExtData(String key)` | `Future<void>` | Remove app ext data for a key. |
| `clearAppExtData()` | `Future<void>` | Remove all app ext data. |

#### User Ext Data — First-Party Data (`user.ext.data`)

| Method | Returns | Description |
|---|---|---|
| `addUserExtData({key, value})` | `Future<void>` | Append a value to user ext data for a key. |
| `updateUserExtData({key, value})` | `Future<void>` | Replace all values for a key with a `Set<String>`. |
| `removeUserExtData(String key)` | `Future<void>` | Remove user ext data for a key. |
| `clearUserExtData()` | `Future<void>` | Remove all user ext data. |

#### Access Control List (`ext.prebid.data`)

| Method | Returns | Description |
|---|---|---|
| `addBidderToAccessControlList(String bidderName)` | `Future<void>` | Grant a bidder access to first-party data. |
| `removeBidderFromAccessControlList(String bidderName)` | `Future<void>` | Revoke a bidder's access. |
| `clearAccessControlList()` | `Future<void>` | Clear the entire access control list. |

#### OpenRTB Configuration & App Info

| Method | Returns | Description |
|---|---|---|
| `setGlobalOrtbConfig(String? ortbConfig)` | `Future<void>` | Set global OpenRTB JSON config merged into every bid request. |
| `getGlobalOrtbConfig()` | `Future<String?>` | Get current global OpenRTB config. |
| `setContentUrl(String? url)` | `Future<void>` | Set content URL (`app.content.url`). |
| `setPublisherName(String? name)` | `Future<void>` | Set publisher name (`app.publisher.name`). |
| `setStoreUrl(String? url)` | `Future<void>` | Set app store URL (`app.storeurl`). |
| `setDomain(String? domain)` | `Future<void>` | Set app domain (`app.domain`). |

---

### `PrebidBannerAd` — Banner Ads

A Flutter `StatefulWidget` that renders a Prebid banner ad using a native `PlatformView`.

| Property | Type | Default | Description |
|---|---|---|---|
| `configId` | `String` | **required** | Prebid Server stored impression configuration ID. |
| `width` | `int` | **required** | Banner width in dp. |
| `height` | `int` | **required** | Banner height in dp. |
| `isVideo` | `bool` | `false` | Set to `true` for outstream video banners. |
| `autoLoad` | `bool` | `true` | Auto-load on widget creation. |
| `refreshIntervalSeconds` | `int?` | `null` | Auto-refresh interval in seconds. Minimum `30`. `null` to disable. |
| `listener` | `PrebidBannerAdListener?` | `null` | Callback listener for ad lifecycle events. |

---

### `PrebidInterstitialAd` — Interstitial Ads

A fullscreen interstitial ad with a load → show → destroy lifecycle.

| Property / Method | Type | Description |
|---|---|---|
| `configId` | `String` | **Required.** Prebid Server config ID. |
| `adFormats` | `Set<AdFormat>?` | Specify `{AdFormat.banner}`, `{AdFormat.video}`, or both. |
| `videoParameters` | `VideoParameters?` | Video playback configuration (protocols, playback methods, etc.). |
| `listener` | `PrebidInterstitialAdListener?` | Callback listener. |
| `loadAd()` | `Future<void>` | Request an interstitial ad. |
| `show()` | `Future<void>` | Present the loaded ad fullscreen. |
| `destroy()` | `Future<void>` | Release all resources. |

---

### `PrebidRewardedAd` — Rewarded Ads

A fullscreen rewarded ad. Users are granted a `PrebidReward` upon completing the ad.

| Property / Method | Type | Description |
|---|---|---|
| `configId` | `String` | **Required.** Prebid Server config ID. |
| `listener` | `PrebidRewardedAdListener?` | Callback listener (includes `onUserEarnedReward`). |
| `loadAd()` | `Future<void>` | Request a rewarded ad. |
| `show()` | `Future<void>` | Present the loaded ad fullscreen. |
| `destroy()` | `Future<void>` | Release all resources. |

**`PrebidReward`:**

| Field | Type | Description |
|---|---|---|
| `type` | `String?` | The reward type (e.g., `"coins"`, `"lives"`). |
| `count` | `int?` | The reward amount. |
| `ext` | `Map<String, dynamic>?` | Optional extra data. |

---

### `PrebidNativeAd` — Native Ads

Loads structured native ad data that you render with your own Flutter widgets.

| Property / Method | Type | Description |
|---|---|---|
| `configId` | `String` | **Required.** Prebid Server config ID. |
| `assets` | `List<NativeAsset>?` | Native assets to request. |
| `eventTrackers` | `List<NativeEventTracker>?` | Event trackers for impression/viewability. |
| `context` | `NativeContextType?` | Content context type. |
| `placementType` | `NativePlacementType?` | Placement type. |
| `placementCount` | `int?` | Number of placements. |
| `listener` | `PrebidNativeAdListener?` | Callback listener. |
| `loadAd()` | `Future<void>` | Request a native ad. |
| `trackImpression()` | `Future<void>` | Fire an impression tracker. |
| `trackClick()` | `Future<void>` | Fire a click tracker. |
| `destroy()` | `Future<void>` | Release all resources. |

---

### `PrebidMultiformatAd` — Multiformat Ads

Combines banner, video, and native in a single bid request.

| Property / Method | Type | Description |
|---|---|---|
| `configId` | `String` | **Required.** Prebid Server config ID. |
| `bannerSizes` | `List<Size>?` | Banner sizes (e.g., `[Size(300, 250)]`). |
| `videoParameters` | `VideoParameters?` | Video config. If non-null, video is included. |
| `nativeAssets` | `List<NativeAsset>?` | Native assets to include. |
| `nativeEventTrackers` | `List<NativeEventTracker>?` | Native event trackers. |
| `isInterstitial` | `bool` | Interstitial multiformat ad. Default: `false`. |
| `isRewarded` | `bool` | Rewarded multiformat ad. Default: `false`. |
| `fetchDemand()` | `Future<PrebidMultiformatBidResponse>` | Execute the bid request. |
| `destroy()` | `Future<void>` | Release resources. |

---

### `PrebidInstreamVideoAd` — In-Stream Video

Fetches VAST video demand from Prebid Server.

| Property / Method | Type | Description |
|---|---|---|
| `configId` | `String` | **Required.** Prebid Server config ID. |
| `size` | `Size` | **Required.** Video player dimensions. |
| `fetchDemand()` | `Future<PrebidVideoAdBidResponse>` | Fetch demand. |
| `destroy()` | `Future<void>` | Release resources. |

---

### `VideoParameters` — Video Configuration

Detailed video ad configuration per the OpenRTB spec.

```dart
const videoParams = VideoParameters(
  mimes: ['video/mp4', 'video/x-ms-wmv'],
  protocols: [VideoProtocol.vast2_0, VideoProtocol.vast3_0],
  playbackMethods: [VideoPlaybackMethod.autoPlaySoundOff],
  placement: VideoPlacement.inBanner,
  maxDuration: 30,
  minDuration: 5,
  api: [VideoApi.vpaid2_0, VideoApi.omid1],
);
```

| Property | Type | Description |
|---|---|---|
| `mimes` | `List<String>` | **Required.** Supported MIME types (`["video/mp4"]`). |
| `protocols` | `List<VideoProtocol>?` | VAST protocol versions. |
| `playbackMethods` | `List<VideoPlaybackMethod>?` | How the video should play. |
| `placement` | `VideoPlacement?` | Placement type (in-stream, in-banner, in-feed, etc.). |
| `maxDuration` | `int?` | Maximum duration in seconds. |
| `minDuration` | `int?` | Minimum duration in seconds. |
| `api` | `List<VideoApi>?` | Supported API frameworks (VPAID, MRAID, OMID). |

---

### `ExternalUserId` — Identity Modules

External user IDs for third-party identity modules.

```dart
await PrebidMobile.setExternalUserIds([
  ExternalUserId(source: 'uidapi.com', identifier: 'uid2-abc-123', atype: 3),
  ExternalUserId(source: 'sharedid.org', identifier: 'shared-xyz', atype: 1),
  ExternalUserId(source: 'liveramp.com', identifier: 'lr-def-456', atype: 3),
]);
```

| Property | Type | Description |
|---|---|---|
| `source` | `String` | Identity module source (e.g., `"uidapi.com"`). |
| `identifier` | `String` | The user ID value. |
| `atype` | `int?` | ID type: `1` = Device, `2` = Person, `3` = User. |
| `ext` | `Map<String, dynamic>?` | Optional extra data. |

**Supported modules:** UID2, SharedID, LiveRamp, Criteo, NetID, and any OpenRTB-compliant source.

---

### Enums

#### `AdFormat`

| Value | Description |
|---|---|
| `banner` | HTML Display ad format. |
| `video` | VAST / Outstream video ad format. |

#### `PrebidLogLevel`

| Value | Description |
|---|---|
| `debug` | Most verbose — all SDK internal messages. |
| `verbose` | Detailed debugging information. |
| `info` | General informational messages. |
| `warn` | Potential issues and warnings. |
| `error` | Errors that may impact functionality. |
| `severe` | Critical errors only. |

#### `InitializationStatus`

| Value | Description |
|---|---|
| `succeeded` | SDK initialized successfully. |
| `failed` | Initialization failed. |
| `serverStatusWarning` | Connected but server returned a warning. |

#### Video Enums

| Enum | Values |
|---|---|
| `VideoProtocol` | `vast1_0`, `vast2_0`, `vast3_0`, `vast4_0`, and their Wrapper variants |
| `VideoPlaybackMethod` | `autoPlaySoundOn`, `autoPlaySoundOff`, `clickToPlay`, `mouseOver`, `enterSoundOn`, `enterSoundOff` |
| `VideoPlacement` | `inStream`, `inBanner`, `inArticle`, `inFeed`, `interstitial` |
| `VideoApi` | `vpaid1_0`, `vpaid2_0`, `mraid1`, `ormma`, `mraid2`, `mraid3`, `omid1` |

#### Native Ad Enums

| Enum | Values | Description |
|---|---|---|
| `NativeImageType` | `icon(1)`, `main(3)`, `custom(500)` | Image sub-type per OpenRTB. |
| `NativeDataType` | `sponsored(1)`, `desc(2)`, `ctaText(12)`, + 10 more | Data asset type per OpenRTB. |
| `NativeEventType` | `impression(1)`, `viewable50(2)`, `viewable100(3)`, `viewableVideo50(4)` | Event types to track. |
| `NativeEventTrackingMethod` | `image(1)`, `js(2)`, `custom(500)` | Tracking method. |
| `NativeContextType` | `contentCentric(1)`, `socialCentric(2)`, `product(3)` | Context in which ad appears. |
| `NativePlacementType` | `inFeed(1)`, `atomicUnit(2)`, `outsideContent(3)`, `recommendation(4)` | Placement within layout. |

---

### Listeners & Callbacks

#### `PrebidBannerAdListener`

| Callback | Signature | Triggered When |
|---|---|---|
| `onAdLoaded` | `void Function()` | Banner content loaded. |
| `onAdFailed` | `void Function(String error)` | Banner failed to load. |
| `onAdClicked` | `void Function()` | User tapped the banner. |
| `onAdClosed` | `void Function()` | Banner overlay was dismissed. |

#### `PrebidInterstitialAdListener`

| Callback | Signature | Triggered When |
|---|---|---|
| `onAdLoaded` | `void Function()` | Interstitial ready to show. |
| `onAdFailed` | `void Function(String error)` | Failed to load. |
| `onAdDisplayed` | `void Function()` | Presented fullscreen. |
| `onAdDismissed` | `void Function()` | User dismissed the ad. |
| `onAdClicked` | `void Function()` | User tapped the ad. |

#### `PrebidRewardedAdListener`

| Callback | Signature | Triggered When |
|---|---|---|
| `onAdLoaded` | `void Function()` | Rewarded ad ready. |
| `onAdFailed` | `void Function(String error)` | Failed to load. |
| `onAdDisplayed` | `void Function()` | Presented fullscreen. |
| `onAdDismissed` | `void Function()` | User dismissed the ad. |
| `onAdClicked` | `void Function()` | User tapped the ad. |
| `onUserEarnedReward` | `void Function(PrebidReward)` | User earned a reward. |

#### `PrebidNativeAdListener`

| Callback | Signature | Triggered When |
|---|---|---|
| `onAdLoaded` | `void Function(PrebidNativeAdResponse)` | Native data ready. |
| `onAdFailed` | `void Function(String error)` | Failed to load. |
| `onAdImpression` | `void Function()` | Impression tracked. |
| `onAdClicked` | `void Function()` | User tapped the ad. |

---

### Error Handling

All SDK errors are encapsulated in `PrebidException`:

```dart
try {
  await interstitial.loadAd();
} on PrebidException catch (e) {
  debugPrint('Error ${e.code}: ${e.message}');
  if (e.details != null) debugPrint('Details: ${e.details}');
}
```

#### `PrebidErrorCode`

| Code | Description |
|---|---|
| `initializationFailed` | SDK failed to initialize. |
| `invalidArguments` | Invalid or missing arguments. |
| `adLoadFailed` | Ad request failed. |
| `adNotFound` | Attempted to show/destroy a non-existent ad. |
| `adDisplayFailed` | Ad could not be displayed. |
| `networkError` | Network request failed. |
| `serverError` | Prebid Server returned an error. |
| `timeout` | Operation timed out. |
| `unknown` | Unclassified error. |

---

## Example App

The `example/` directory contains a full-featured demo app including:

- **30+ test cases** across Banner, Interstitial, Rewarded, Native, Video, and Multiformat
- **Live event logger** with timestamps for every SDK callback
- **Settings panel** with persistent GDPR/COPPA toggles and server configuration
- **Targeting data page** for user keywords, app ext data, and OpenRTB config

```bash
cd example
flutter pub get
flutter run
```

See [example/README.md](example/README.md) for detailed documentation.

---

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on the [GitHub repository](https://github.com/thanhhaidev/prebid-mobile-flutter).

---

## License

[Apache License 2.0](LICENSE)
