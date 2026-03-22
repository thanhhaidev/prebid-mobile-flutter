# Prebid Mobile Flutter

A comprehensive Flutter plugin that wraps the [Prebid Mobile SDK](https://docs.prebid.org/prebid-mobile/prebid-mobile-getting-started.html) for Android (`3.3.0`) and iOS (`~> 3.1`), providing a unified Dart API for header bidding ads.

This plugin currently focuses on the **Prebid Rendered (In-App)** approach, meaning the Prebid SDK handles both the bidding and the rendering of the ad directly, without requiring an external primary ad server.

[![pub package](https://img.shields.io/pub/v/prebid_mobile_flutter.svg)](https://pub.dev/packages/prebid_mobile_flutter)
[![Flutter CI](https://github.com/thanhhaidev/prebid-mobile-flutter/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/thanhhaidev/prebid-mobile-flutter/actions/workflows/flutter_ci.yml)

## Supported Ad Formats

- ✅ **Banner Ads** (Display & Video) — Native `PlatformView` widget
- ✅ **Interstitial Ads** (Display & Video) — Fullscreen modal ads
- ✅ **Rewarded Ads** (Display & Video) — Fullscreen ads with callback rewards
- ✅ **Native Ads** — Custom asset rendering (Title, Icon, Main Image, CTA, Description, Sponsored By)
- ✅ **Multiformat** — Support for multiple ad formats on a single ad unit

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| Flutter  | 3.41.0         |
| Dart     | ^3.11.0        |
| Android  | API 24         |
| iOS      | 13.0           |

## Installation

Add the plugin to your `pubspec.yaml`:

```yaml
dependencies:
  prebid_mobile_flutter: latest_version
```

### iOS Setup
The PrebidMobile iOS SDK requires iOS 13.0+. Ensure your `ios/Podfile` has `platform :ios, '13.0'` and run:
```bash
cd ios && pod install
```

## Quick Start

### 1. Initialize the SDK

Before loading any ads, initialize the SDK with your Prebid Server URL and Account ID:

```dart
import 'package:prebid_mobile_flutter/prebid_mobile_flutter.dart';

await PrebidMobile.initializeSdk(
  prebidServerUrl: 'https://prebid-server-test-j.prebid.org/openrtb2/auction',
  accountId: '0689a263-318d-448b-a3d4-b02e8a709d9d',
  completion: (status, error) {
    if (status == InitializationStatus.succeeded) {
      print('Prebid SDK ready!');
    }
  },
);
```

### 2. Banner Ad (Display or Video)

Use the `PrebidBannerAd` widget to inline banners. Use the `adFormats` property to specify if it's a display or video banner.

```dart
PrebidBannerAd(
  configId: 'prebid-demo-banner-320-50',
  width: 320,
  height: 50,
  adFormats: {AdFormat.banner}, // Or {AdFormat.video} for Video Banners
  listener: PrebidBannerAdListener(
    onAdLoaded: () => print('Banner loaded'),
    onAdFailed: (error) => print('Banner failed: $error'),
    onAdClicked: () => print('Banner clicked'),
  ),
)
```

### 3. Interstitial Ad

Interstitials are full-screen ads. They must be loaded first, then shown.

```dart
final interstitial = PrebidInterstitialAd(
  configId: 'prebid-demo-display-interstitial-320-480',
  adFormats: {AdFormat.banner}, // Or {AdFormat.video}
  listener: PrebidInterstitialAdListener(
    onAdLoaded: () => print('Interstitial loaded'),
    onAdFailed: (error) => print('Failed: $error'),
    onAdDismissed: () => print('Dismissed'),
  ),
);

// 1. Load the ad
await interstitial.loadAd();

// 2. Show the ad when ready
await interstitial.show();

// 3. Clean up
await interstitial.destroy();
```

### 4. Rewarded Ad

Rewarded ads grant users items/currency for watching a video.

```dart
final rewarded = PrebidRewardedAd(
  configId: 'prebid-demo-video-rewarded-320-480',
  listener: PrebidRewardedAdListener(
    onAdLoaded: () => print('Rewarded loaded'),
    onUserEarnedReward: (reward) {
      print('User earned: ${reward.count}x ${reward.type}');
    },
    onAdClosed: () => print('Rewarded ad closed'),
  ),
);

await rewarded.loadAd();
await rewarded.show();
await rewarded.destroy();
```

### 5. Native Ad

Native ads give you the raw assets (Title, Icon, Image, CTA, etc.) to render your own custom UI.

```dart
final nativeAd = PrebidNativeAd(
  configId: 'prebid-demo-banner-native-styles',
  listener: PrebidNativeAdListener(
    onAdLoaded: (assets) {
      print('Native loaded! Title: ${assets.title}, CTA: ${assets.callToAction}');
      // setState to render the assets in your Flutter UI
    },
    onAdFailed: (error) => print('Failed: $error'),
  ),
);

// Configure the assets you want to request
nativeAd.addNativeAsset(NativeAssetTitle(length: 90, required: true));
nativeAd.addNativeAsset(NativeAssetIcon(width: 50, height: 50, required: true));
nativeAd.addNativeAsset(NativeAssetImage(width: 1200, height: 627, required: true));
nativeAd.addNativeAsset(NativeAssetData(type: NativeDataAssetType.sponsored, required: true));
nativeAd.addNativeAsset(NativeAssetData(type: NativeDataAssetType.description, required: true));

await nativeAd.loadAd();

// After rendering the native ad UI, register the tap tracking:
// nativeAd.registerView(context);
```

## Global Configuration & Targeting

You can configure global settings for the Prebid SDK, including privacy laws and demographic targeting.

```dart
// Debug & Logging
await PrebidMobile.setPbsDebug(true);
await PrebidMobile.setLogLevel(PrebidLogLevel.debug);

// Privacy
await PrebidTargeting.setSubjectToGDPR(true);
await PrebidTargeting.setSubjectToCOPPA(true);

// First-Party Data & Targeting
await PrebidTargeting.addUserKeyword('sports');
await PrebidTargeting.addAppKeyword('news');
await PrebidTargeting.addAppExtData(key: 'userSegment', value: 'premium');
```

## Example App

Check out the `example/` directory for a full-featured showcase replicating the official native iOS PrebidDemo app, including:
- 30+ Test cases covering all ad formats
- Detailed event log tracking
- Settings panel with persistent Configuration & Targeting

## License

[Apache License 2.0](LICENSE)
