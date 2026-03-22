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
| **Banner Ads** | Display and video banners via native `PlatformView` widgets. |
| **Interstitial Ads** | Fullscreen display and video ads with load/show lifecycle. |
| **Rewarded Ads** | Fullscreen ads that grant users a typed reward on completion. |
| **Native Ads** | Fetch raw native assets (Title, Image, Icon, CTA, Sponsored, Description) and render custom Flutter UIs. |
| **Multiformat Ads** | Request banner, video, and native demand on a single ad unit simultaneously. |
| **In-Stream Video** | Fetch VAST video demand for integration with your own player or ad server. |
| **Privacy & Compliance** | Built-in GDPR, COPPA, TCFv2 purpose consents, and access control list management. |
| **First-Party Data** | User keywords, app keywords, app ext data, and global OpenRTB config for enriched bid requests. |
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
  adFormats: {AdFormat.banner},
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

---

## API Reference

### `PrebidMobile` — SDK Configuration

Static class for SDK initialization and global configuration.

| Method | Returns | Description |
|---|---|---|
| `initializeSdk({prebidServerUrl, accountId, completion})` | `Future<void>` | Initialize the SDK with your Prebid Server endpoint and account ID. The `completion` callback receives an `InitializationStatus` and an optional error message. |
| `setTimeoutMillis(int timeout)` | `Future<void>` | Set the bid request timeout in milliseconds. Default varies by platform. |
| `setShareGeoLocation(bool share)` | `Future<void>` | Enable or disable sharing the device's geo location in bid requests. |
| `setPbsDebug(bool enabled)` | `Future<void>` | Enable PBS debug mode. Adds `"test": 1` to outgoing bid requests, which tells the server to return test ads. |
| `setLogLevel(PrebidLogLevel level)` | `Future<void>` | Set the SDK log verbosity. Values: `debug`, `verbose`, `info`, `warn`, `error`, `severe`. |
| `setCustomHeaders(Map<String, String> headers)` | `Future<void>` | Set custom HTTP headers to be included with every bid request. |
| `setStoredAuctionResponse(String response)` | `Future<void>` | Set a stored auction response ID for deterministic testing (bypasses live auction). |
| `clearStoredAuctionResponse()` | `Future<void>` | Remove any previously set stored auction response. |
| `addStoredBidResponse(String bidder, String responseId)` | `Future<void>` | Add a stored bid response for a specific bidder. |
| `clearStoredBidResponses()` | `Future<void>` | Remove all stored bid responses. |
| `setCreativeFactoryTimeout(int timeout)` | `Future<void>` | Set the timeout (ms) for the HTML creative factory (banner ads). |
| `setCreativeFactoryTimeoutPreRenderContent(int timeout)` | `Future<void>` | Set the timeout (ms) for the pre-render content creative factory (video ads). |
| `setCustomStatusEndpoint(String endpoint)` | `Future<void>` | Override the default Prebid Server status endpoint URL. |

---

### `PrebidTargeting` — Privacy & Targeting

Static class for managing privacy consent, first-party data, and targeting parameters.

#### Privacy & Consent

| Method | Returns | Description |
|---|---|---|
| `setSubjectToCOPPA(bool? subject)` | `Future<void>` | Flag the request as subject to Children's Online Privacy Protection Act (COPPA). Pass `null` to clear. |
| `getSubjectToCOPPA()` | `Future<bool?>` | Get the current COPPA subject status. |
| `setSubjectToGDPR(bool? subject)` | `Future<void>` | Flag the request as subject to General Data Protection Regulation (GDPR). Pass `null` to clear. |
| `getSubjectToGDPR()` | `Future<bool?>` | Get the current GDPR subject status. |
| `setGDPRConsentString(String? consent)` | `Future<void>` | Set the IAB TCF consent string. |
| `getGDPRConsentString()` | `Future<String?>` | Get the current GDPR consent string. |
| `setPurposeConsents(String? consents)` | `Future<void>` | Set the TCFv2 purpose consents string (binary string of purpose IDs). |
| `getPurposeConsents()` | `Future<String?>` | Get the current TCFv2 purpose consents. |
| `getDeviceAccessConsent()` | `Future<bool?>` | Get the device access consent (TCFv2 Purpose 1 — Store and/or access information on a device). |

#### User Keywords (`user.keywords`)

| Method | Returns | Description |
|---|---|---|
| `addUserKeyword(String keyword)` | `Future<void>` | Add a single user keyword for targeting. |
| `addUserKeywords(Set<String> keywords)` | `Future<void>` | Add multiple user keywords at once. |
| `removeUserKeyword(String keyword)` | `Future<void>` | Remove a single user keyword. |
| `clearUserKeywords()` | `Future<void>` | Remove all user keywords. |
| `getUserKeywords()` | `Future<List<String>>` | Retrieve all currently set user keywords. |

#### App Keywords (`app.keywords`)

| Method | Returns | Description |
|---|---|---|
| `addAppKeyword(String keyword)` | `Future<void>` | Add a single app keyword. |
| `addAppKeywords(Set<String> keywords)` | `Future<void>` | Add multiple app keywords at once. |
| `removeAppKeyword(String keyword)` | `Future<void>` | Remove a single app keyword. |
| `clearAppKeywords()` | `Future<void>` | Remove all app keywords. |

#### App Ext Data — First-Party Data (`app.ext.data`)

| Method | Returns | Description |
|---|---|---|
| `addAppExtData({key, value})` | `Future<void>` | Append a value to the app ext data for a given key. |
| `updateAppExtData({key, value})` | `Future<void>` | Replace all ext data values for a given key with a new `Set<String>`. |
| `removeAppExtData(String key)` | `Future<void>` | Remove app ext data for a given key. |
| `clearAppExtData()` | `Future<void>` | Remove all app ext data. |

#### Access Control List (`ext.prebid.data`)

| Method | Returns | Description |
|---|---|---|
| `addBidderToAccessControlList(String bidderName)` | `Future<void>` | Grant a specific bidder access to first-party data. |
| `removeBidderFromAccessControlList(String bidderName)` | `Future<void>` | Revoke a bidder's access to first-party data. |
| `clearAccessControlList()` | `Future<void>` | Clear the entire access control list. |

#### OpenRTB Configuration & App Info

| Method | Returns | Description |
|---|---|---|
| `setGlobalOrtbConfig(String? ortbConfig)` | `Future<void>` | Set a global OpenRTB JSON config that will be merged into every bid request (e.g., `bcat`, `badv`). |
| `getGlobalOrtbConfig()` | `Future<String?>` | Get the current global OpenRTB config JSON string. |
| `setContentUrl(String? url)` | `Future<void>` | Set the content URL for contextual targeting. |
| `setPublisherName(String? name)` | `Future<void>` | Set the publisher name (`app.publisher.name`). |
| `setStoreUrl(String? url)` | `Future<void>` | Set the app store URL (`app.storeurl`). |
| `setDomain(String? domain)` | `Future<void>` | Set the app domain (`app.domain`). |

---

### `PrebidBannerAd` — Banner Ads

A Flutter `StatefulWidget` that renders a Prebid banner ad using a native `PlatformView` (Android: `AndroidView`, iOS: `UiKitView`).

| Property | Type | Default | Description |
|---|---|---|---|
| `configId` | `String` | **required** | The Prebid Server stored impression configuration ID. |
| `width` | `int` | **required** | The desired banner width in density-independent pixels (dp). |
| `height` | `int` | **required** | The desired banner height in dp. |
| `isVideo` | `bool` | `false` | Set to `true` to request an outstream video banner. |
| `autoLoad` | `bool` | `true` | Whether the ad should load automatically on widget creation. |
| `listener` | `PrebidBannerAdListener?` | `null` | Callback listener for ad lifecycle events. |

---

### `PrebidInterstitialAd` — Interstitial Ads

A fullscreen interstitial ad with a load → show → destroy lifecycle.

| Property / Method | Type | Description |
|---|---|---|
| `configId` | `String` | **Required.** The Prebid Server stored impression configuration ID. |
| `adFormats` | `Set<AdFormat>?` | Optional. Specify `{AdFormat.banner}`, `{AdFormat.video}`, or both. |
| `listener` | `PrebidInterstitialAdListener?` | Callback listener for ad lifecycle events. |
| `loadAd()` | `Future<void>` | Request an interstitial ad from Prebid Server. |
| `show()` | `Future<void>` | Present the loaded interstitial ad in fullscreen. |
| `destroy()` | `Future<void>` | Release all resources. Must be called after use. |

---

### `PrebidRewardedAd` — Rewarded Ads

A fullscreen rewarded ad. Users are granted a `PrebidReward` upon completing the ad.

| Property / Method | Type | Description |
|---|---|---|
| `configId` | `String` | **Required.** The Prebid Server stored impression configuration ID. |
| `listener` | `PrebidRewardedAdListener?` | Callback listener (includes `onUserEarnedReward`). |
| `loadAd()` | `Future<void>` | Request a rewarded ad from Prebid Server. |
| `show()` | `Future<void>` | Present the loaded rewarded ad in fullscreen. |
| `destroy()` | `Future<void>` | Release all resources. Must be called after use. |

**`PrebidReward`:**

| Field | Type | Description |
|---|---|---|
| `type` | `String?` | The reward type (e.g., `"coins"`, `"lives"`). |
| `count` | `int?` | The reward amount. |
| `ext` | `Map<String, dynamic>?` | Optional extra data from the reward payload. |

---

### `PrebidNativeAd` — Native Ads

Loads structured native ad data (title, images, CTA, etc.) that you render with your own Flutter widgets.

| Property / Method | Type | Description |
|---|---|---|
| `configId` | `String` | **Required.** The Prebid Server config ID. |
| `assets` | `List<NativeAsset>?` | The native assets to request (`title`, `image`, `data`). |
| `eventTrackers` | `List<NativeEventTracker>?` | Event trackers for impression and viewability. |
| `context` | `NativeContextType?` | Content context type. |
| `placementType` | `NativePlacementType?` | Placement type. |
| `placementCount` | `int?` | Number of placements in the layout. |
| `listener` | `PrebidNativeAdListener?` | Callback listener. `onAdLoaded` provides a `PrebidNativeAdResponse`. |
| `loadAd()` | `Future<void>` | Request a native ad from Prebid Server. |
| `trackImpression()` | `Future<void>` | Manually fire an impression tracker. |
| `trackClick()` | `Future<void>` | Manually fire a click tracker. |
| `destroy()` | `Future<void>` | Release all resources. |

**`NativeAsset` constructors:**

| Constructor | Key Parameters | Description |
|---|---|---|
| `NativeAsset.title({length, required})` | `length`: max chars (default `90`) | Request a title text asset. |
| `NativeAsset.image({imageType, width, height, ...})` | `imageType`: `NativeImageType.icon` or `.main` | Request an icon or main image asset. |
| `NativeAsset.data({dataType, length, required})` | `dataType`: `NativeDataType.sponsored`, `.desc`, `.ctaText`, etc. | Request a data asset. |

**`PrebidNativeAdResponse`:**

| Field | Type | Description |
|---|---|---|
| `title` | `String?` | The title text. |
| `text` | `String?` | The description / body text. |
| `iconUrl` | `String?` | URL of the icon image. |
| `imageUrl` | `String?` | URL of the main image. |
| `sponsoredBy` | `String?` | The sponsor name. |
| `callToAction` | `String?` | CTA text (e.g., "Install", "Learn More"). |
| `clickUrl` | `String?` | The click-through URL. |

---

### `PrebidMultiformatAd` — Multiformat Ads

Combines banner, video, and native in a single bid request using `PrebidAdUnit` + `PrebidRequest`.

| Property / Method | Type | Description |
|---|---|---|
| `configId` | `String` | **Required.** The Prebid Server config ID. |
| `bannerSizes` | `List<Size>?` | Banner sizes to include (e.g., `[Size(300, 250)]`). |
| `includeVideo` | `bool` | Whether to include video in the bid request. Default: `false`. |
| `nativeAssets` | `List<NativeAsset>?` | Native assets to include. |
| `nativeEventTrackers` | `List<NativeEventTracker>?` | Native event trackers. |
| `isInterstitial` | `bool` | Whether this is an interstitial multiformat ad. Default: `false`. |
| `isRewarded` | `bool` | Whether this is a rewarded multiformat ad. Default: `false`. |
| `fetchDemand()` | `Future<PrebidMultiformatBidResponse>` | Execute the bid request. Returns result code, winning format, keywords, and native cache ID. |
| `destroy()` | `Future<void>` | Release resources. |

**`PrebidMultiformatBidResponse`:**

| Field | Type | Description |
|---|---|---|
| `resultCode` | `String` | Result code (e.g., `"prebidDemandFetchSuccess"`, `"prebidDemandNoBids"`). |
| `winningFormat` | `String?` | The format that won: `"banner"`, `"video"`, or `"native"`. |
| `targetingKeywords` | `Map<String, String>?` | Targeting keywords to pass to an ad server. |
| `nativeAdCacheId` | `String?` | Cache ID for native ad data (only when `winningFormat == "native"`). |
| `isSuccess` | `bool` | Convenience getter — `true` if `resultCode` is `"prebidDemandFetchSuccess"`. |

---

### `PrebidInstreamVideoAd` — In-Stream Video

Fetches VAST video demand from Prebid Server. The returned targeting keywords can be passed to your ad server (e.g., GAM) to load the winning creative.

| Property / Method | Type | Description |
|---|---|---|
| `configId` | `String` | **Required.** The Prebid Server config ID. |
| `size` | `Size` | **Required.** The video player dimensions. |
| `fetchDemand()` | `Future<PrebidVideoAdBidResponse>` | Fetch demand. Returns result code and targeting keywords. |
| `destroy()` | `Future<void>` | Release resources. |

---

### Enums

#### `AdFormat`

| Value | Description |
|---|---|
| `banner` | HTML Display ad format. |
| `video` | VAST / Outstream video ad format. |

#### `PrebidLogLevel`

| Value | Index | Description |
|---|---|---|
| `debug` | 0 | Most verbose. All SDK internal messages. |
| `verbose` | 1 | Detailed information for debugging. |
| `info` | 2 | General informational messages. |
| `warn` | 3 | Potential issues and warnings. |
| `error` | 4 | Errors that may impact functionality. |
| `severe` | 5 | Critical errors only. |

#### `InitializationStatus`

| Value | Description |
|---|---|
| `succeeded` | SDK initialized successfully. |
| `failed` | Initialization failed (check the error message). |
| `serverStatusWarning` | Connected but the server returned a warning. |

#### Native Ad Enums

| Enum | Values | Description |
|---|---|---|
| `NativeAssetType` | `title`, `image`, `data` | Type of native asset in the request. |
| `NativeImageType` | `icon(1)`, `main(3)`, `custom(500)` | Image sub-type per OpenRTB spec. |
| `NativeDataType` | `sponsored(1)`, `desc(2)`, `rating(3)`, `likes(4)`, `downloads(5)`, `price(6)`, `salePrice(7)`, `phone(8)`, `address(9)`, `desc2(10)`, `displayUrl(11)`, `ctaText(12)`, `custom(500)` | Data asset type per OpenRTB spec. |
| `NativeEventType` | `impression(1)`, `viewable50(2)`, `viewable100(3)`, `viewableVideo50(4)`, `custom(500)` | Event types to track. |
| `NativeEventTrackingMethod` | `image(1)`, `js(2)`, `custom(500)` | Tracking method for native events. |
| `NativeContextType` | `contentCentric(1)`, `socialCentric(2)`, `product(3)`, `custom(500)` | Context in which the ad appears. |
| `NativePlacementType` | `inFeed(1)`, `atomicUnit(2)`, `outsideContent(3)`, `recommendation(4)`, `custom(500)` | Placement within the content layout. |

---

### Listeners & Callbacks

#### `PrebidBannerAdListener`

| Callback | Signature | Triggered When |
|---|---|---|
| `onAdLoaded` | `void Function()` | The banner ad content has loaded. |
| `onAdFailed` | `void Function(String error)` | The banner ad failed to load. |
| `onAdClicked` | `void Function()` | The user tapped the banner ad. |
| `onAdClosed` | `void Function()` | A fullscreen overlay from the banner was dismissed. |

#### `PrebidInterstitialAdListener`

| Callback | Signature | Triggered When |
|---|---|---|
| `onAdLoaded` | `void Function()` | The interstitial ad is ready to show. |
| `onAdFailed` | `void Function(String error)` | The interstitial failed to load. |
| `onAdDisplayed` | `void Function()` | The interstitial was presented fullscreen. |
| `onAdDismissed` | `void Function()` | The user dismissed the interstitial. |
| `onAdClicked` | `void Function()` | The user tapped the interstitial. |

#### `PrebidRewardedAdListener`

| Callback | Signature | Triggered When |
|---|---|---|
| `onAdLoaded` | `void Function()` | The rewarded ad is ready to show. |
| `onAdFailed` | `void Function(String error)` | The rewarded ad failed to load. |
| `onAdDisplayed` | `void Function()` | The rewarded ad was presented fullscreen. |
| `onAdDismissed` | `void Function()` | The user dismissed the rewarded ad. |
| `onAdClicked` | `void Function()` | The user tapped the rewarded ad. |
| `onUserEarnedReward` | `void Function(PrebidReward reward)` | The user completed the ad and earned a reward. |

#### `PrebidNativeAdListener`

| Callback | Signature | Triggered When |
|---|---|---|
| `onAdLoaded` | `void Function(PrebidNativeAdResponse response)` | Native ad data is ready. Use the response fields to build your custom UI. |
| `onAdFailed` | `void Function(String error)` | The native ad failed to load. |
| `onAdImpression` | `void Function()` | An impression was tracked for the native ad. |
| `onAdClicked` | `void Function()` | The user tapped the native ad. |

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
| `initializationFailed` | The SDK failed to initialize. |
| `invalidArguments` | Invalid or missing arguments were provided. |
| `adLoadFailed` | The ad request failed. |
| `adNotFound` | Attempted to show or destroy a non-existent ad. |
| `adDisplayFailed` | The ad could not be displayed. |
| `networkError` | A network request failed. |
| `serverError` | Prebid Server returned an error. |
| `timeout` | The operation timed out. |
| `unknown` | An unclassified error occurred. |

---

## Example App

The `example/` directory contains a full-featured demo app replicating the official native Prebid iOS demo, including:

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
