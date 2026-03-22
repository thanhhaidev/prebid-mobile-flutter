# Prebid Mobile Flutter

A Flutter plugin that wraps the [Prebid Mobile SDK](https://docs.prebid.org/prebid-mobile/prebid-mobile-getting-started.html) for Android and iOS, providing a unified Dart API for header bidding ads.

Uses the **Prebid Rendered** approach — the SDK handles both bidding and rendering (no external ad server required).

## Features

- ✅ **SDK Initialization** — Configure Prebid Server URL, account ID, timeout, geo, debug mode
- ✅ **Banner Ads** — Native `PlatformView` widget with auto-load support
- ✅ **Interstitial Ads** — Fullscreen ads with load/show lifecycle
- ✅ **Rewarded Ads** — Fullscreen ads with reward callbacks

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| Flutter  | 3.41.5         |
| Dart     | ^3.11.0        |
| Android  | API 24         |
| iOS      | 13.0           |

## Installation

Add the plugin to your `pubspec.yaml`:

```yaml
dependencies:
  prebid_mobile_flutter:
    path: ../prebid-mobile-flutter  # or publish to pub.dev
```

### Android

The Prebid Mobile SDK (`3.3.0`) is automatically included via Maven.

### iOS

The PrebidMobile SDK (`~> 3.1`) is automatically included via CocoaPods. Run:

```bash
cd ios && pod install
```

## Quick Start

### 1. Initialize the SDK

```dart
import 'package:prebid_mobile_flutter/prebid_mobile_flutter.dart';

await PrebidMobile.initializeSdk(
  prebidServerUrl: 'https://your-server.com/openrtb2/auction',
  accountId: 'your-account-id',
  completion: (status, error) {
    if (status == InitializationStatus.succeeded) {
      print('Prebid SDK ready!');
    }
  },
);
```

### 2. Banner Ad

```dart
PrebidBannerAd(
  configId: 'your-stored-impression-id',
  width: 320,
  height: 50,
  listener: PrebidBannerAdListener(
    onAdLoaded: () => print('Banner loaded'),
    onAdFailed: (error) => print('Banner failed: $error'),
    onAdClicked: () => print('Banner clicked'),
  ),
)
```

### 3. Interstitial Ad

```dart
final interstitial = PrebidInterstitialAd(
  configId: 'your-stored-impression-id',
  adFormats: {AdFormat.banner},
  listener: PrebidInterstitialAdListener(
    onAdLoaded: () => print('Interstitial loaded'),
    onAdFailed: (error) => print('Failed: $error'),
    onAdDismissed: () => print('Dismissed'),
  ),
);

await interstitial.loadAd();
// When ready to show:
await interstitial.show();
// Clean up:
await interstitial.destroy();
```

### 4. Rewarded Ad

```dart
final rewarded = PrebidRewardedAd(
  configId: 'your-stored-impression-id',
  listener: PrebidRewardedAdListener(
    onAdLoaded: () => print('Rewarded loaded'),
    onUserEarnedReward: (reward) {
      print('Earned: ${reward.count}x ${reward.type}');
    },
  ),
);

await rewarded.loadAd();
await rewarded.show();
await rewarded.destroy();
```

## SDK Configuration

```dart
// Timeout for bid requests (ms)
await PrebidMobile.setTimeoutMillis(3000);

// Share geo location
await PrebidMobile.setShareGeoLocation(true);

// Debug mode (adds "test":1 to requests)
await PrebidMobile.setPbsDebug(true);

// Log level
await PrebidMobile.setLogLevel(PrebidLogLevel.debug);

// Custom HTTP headers
await PrebidMobile.setCustomHeaders({'X-Custom': 'value'});

// Stored auction response (for testing)
await PrebidMobile.setStoredAuctionResponse('response-id');

// Creative factory timeouts
await PrebidMobile.setCreativeFactoryTimeout(7000);
await PrebidMobile.setCreativeFactoryTimeoutPreRenderContent(25000);
```

## API Reference

### PrebidMobile

| Method | Description |
|--------|-------------|
| `initializeSdk(prebidServerUrl, accountId, completion)` | Initialize SDK |
| `setTimeoutMillis(int)` | Bid request timeout |
| `setShareGeoLocation(bool)` | Enable/disable geo |
| `setPbsDebug(bool)` | Debug flag |
| `setCustomHeaders(Map)` | Custom HTTP headers |
| `setStoredAuctionResponse(String)` | For testing |
| `addStoredBidResponse(bidder, responseId)` | Stored bid response |
| `clearStoredBidResponses()` | Clear stored responses |
| `setLogLevel(PrebidLogLevel)` | Log verbosity |
| `setCreativeFactoryTimeout(int)` | Banner creative timeout |
| `setCreativeFactoryTimeoutPreRenderContent(int)` | Video creative timeout |
| `setCustomStatusEndpoint(String)` | Custom status endpoint |

### Ad Units

| Class | Type | Rendering |
|-------|------|-----------|
| `PrebidBannerAd` | Widget (PlatformView) | Inline |
| `PrebidInterstitialAd` | Fullscreen | Modal |
| `PrebidRewardedAd` | Fullscreen + Reward | Modal |

## Testing

Use Prebid's community test server and config IDs:

```dart
const prebidServerUrl = 'https://prebid-server-test-j.prebid.org/openrtb2/auction';
const accountId = '0689a263-318d-448b-a3d4-b02e8a709d9d';
const bannerConfigId = 'prebid-demo-banner-320-50';
const interstitialConfigId = 'prebid-demo-display-interstitial-320-480';
const rewardedConfigId = 'prebid-demo-video-rewarded-320-480';
```

## Example App

The `example/` directory contains a comprehensive demo app showcasing all ad formats:

- **36 test cases** covering Banner, Video, Interstitial, Rewarded, Native, Multiformat, and MRAID
- **Settings persistence** with SharedPreferences (server URL, account ID, privacy toggles)
- **Dark mode** toggle with real-time theme switching
- **User targeting** configuration (keywords, ext data, ORTB config)
- **Event logging** with real-time log viewer and ad load timing
- **About page** with SDK version, platform info, and documentation links

```bash
cd example
flutter pub get
flutter run
```

See [example/README.md](example/README.md) for full documentation.

## License

Apache License 2.0
