# Prebid Mobile Flutter

[![pub package](https://img.shields.io/pub/v/prebid_mobile_sdk.svg)](https://pub.dev/packages/prebid_mobile_sdk)
[![Flutter CI](https://github.com/thanhhaidev/prebid-mobile-flutter/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/thanhhaidev/prebid-mobile-flutter/actions/workflows/flutter_ci.yml)

> **Unofficial project.** This is an independent, community-maintained
> Flutter wrapper around the official
> [Prebid Mobile SDKs](https://docs.prebid.org/prebid-mobile/prebid-mobile-getting-started.html).
> It is not affiliated with, endorsed by, or maintained by Prebid.org. Report
> issues with this plugin in [its repository](https://github.com/thanhhaidev/prebid-mobile-flutter/issues),
> not to Prebid.

A comprehensive Flutter plugin wrapping the [Prebid Mobile SDK](https://docs.prebid.org/prebid-mobile/prebid-mobile-getting-started.html) for **Android** and **iOS**.

**Documentation:** [thanhhaidev.github.io/prebid-mobile-flutter](https://thanhhaidev.github.io/prebid-mobile-flutter/)

This plugin focuses on the **Prebid Rendered (In-App Bidding)** approach — the Prebid SDK handles both the auction and rendering directly, with no external ad server required.

---

## Table of Contents

- [Features](#features)
- [Platform Requirements](#platform-requirements) (native Prebid SDK versions)
- [Installation](#installation)
- [Getting Started](#getting-started)
- [Error Handling](#error-handling)
- [Documentation](#documentation)
- [Ad Server Integration](#ad-server-integration)
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
| **Native Ads** | Load native ads and show them with `PrebidNativeAdView` (native rendering with impression/click tracking); raw assets are also exposed. |
| **Multiformat Ads** | Request banner, video, and native demand on a single ad unit simultaneously. |
| **In-Stream Video** | Fetch VAST video demand for integration with your own player or ad server. |
| **Video Parameters** | Full OpenRTB video configuration — protocols, playback methods, placement, duration limits. |
| **External User IDs** | Third-party identity modules (UID2, SharedID, LiveRamp, etc.) for improved fill rates. |
| **Privacy & Compliance** | GDPR, COPPA, TCFv2, CCPA/US Privacy, and GPP consent support. |
| **First-Party Data** | User/app keywords, user/app ext data, access control list, and global OpenRTB config. |
| **Stored Responses** | Stored auction and bid responses for deterministic testing without live auctions. |

---

## Platform Requirements

Each release bundles a fixed Prebid Mobile SDK version per platform:

<!-- compatibility:start -->
<!-- Generated from website/src/data/compatibility.json by website/scripts/sync-compatibility.mjs. Do not edit. -->

| prebid_mobile_sdk | Prebid Android | Prebid iOS | Android | iOS | Flutter | Dart |
| --- | --- | --- | --- | --- | --- | --- |
| 1.0.0 | `3.4.0` | `>= 3.4.1, < 4.0` | API 24+ | 15.0+ | `>=3.44.0` | `^3.12.0` |

Android resolves exactly the listed Prebid version. On iOS, CocoaPods and Swift Package Manager pick the newest PrebidMobile release in the range, so a fresh `pod install` can resolve a newer 3.x patch.

Full mapping: [Compatibility](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/compatibility).

<!-- compatibility:end -->

---

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  prebid_mobile_sdk: ^1.0.0
```

### iOS

Ensure your `ios/Podfile` specifies `platform :ios, '15.0'`, then run:

```bash
cd ios && pod install
```

Swift Package Manager is supported too (the plugin ships a
`Package.swift`). With Swift Package Manager, Xcode also resolves Google Mobile Ads and AppLovin, because Prebid's `Package.swift` declares them for its adapter products, even though the core package only links `PrebidMobile`. An app that pins Google Mobile Ads 12 or AppLovin below 13 can't resolve with Swift Package Manager; CocoaPods doesn't have this issue.

### Android

No additional setup needed. The Prebid Mobile Android SDK is included automatically via Maven.

---

## Getting Started

### 1. Initialize the SDK

Call `PrebidMobile.initializeSdk` once at app launch, before loading any ads:

```dart
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PrebidMobile.initializeSdk(
    prebidServerUrl: 'https://prebid-server-test-j.prebid.org/openrtb2/auction',
    accountId: '0689a263-318d-448b-a3d4-b02e8a709d9d',
    completion: (status, error) {
      if (status == PrebidInitializationStatus.succeeded) {
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
  adFormats: {PrebidAdFormat.banner, PrebidAdFormat.video},
  videoParameters: const VideoParameters(
    mimes: ['video/mp4'],
    protocols: [VideoProtocol.vast2_0, VideoProtocol.vast3_0],
    playbackMethods: [VideoPlaybackMethod.autoPlaySoundOff],
  ),
  listener: PrebidInterstitialAdListener(
    onAdLoaded: () async => await interstitial.show(),
    onAdClosed: () async => await interstitial.destroy(),
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
    onAdClosed: () async => await rewarded.destroy(),
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

## Error Handling

Ad load, show and render failures are not thrown: they arrive through the
listener's `onAdFailed` callback with the native SDK's error message.

```dart
PrebidInterstitialAdListener(
  onAdFailed: (error) => debugPrint('Interstitial failed: $error'),
)
```

Every other call returns a `Future` that completes once the native SDK has
applied it. It only fails when the platform call itself fails (for example a
`PlatformException` when the plugin isn't registered).

Await `PrebidMobile.initializeSdk()` before loading ads. Prebid Android
drops requests made before initialization completes; the plugin reports them
as `onAdFailed`, or as the `prebidSdkNotInitialized` result code from
`fetchDemand()`.

---
---

## Documentation

The guides on the [documentation site](https://thanhhaidev.github.io/prebid-mobile-flutter/)
cover every option; the [API reference](https://pub.dev/documentation/prebid_mobile_sdk/latest/)
documents every class, listener and enum.

| Topic | Guide |
|---|---|
| SDK options, timeouts, external user IDs, stored responses | [Configuration](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/configuration) |
| GDPR, TCF, CCPA / US Privacy, GPP, COPPA | [Privacy](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/privacy) |
| Keywords, first-party data, OpenRTB config, app info | [Targeting](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/targeting) |
| `PrebidBannerAd` and its controller | [Banner](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/banner) |
| `PrebidInterstitialAd`, `PrebidRewardedAd` | [Interstitial & rewarded](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/fullscreen) |
| `PrebidNativeAd`, `PrebidNativeAdView`, native assets | [Native](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/native) |
| `VideoParameters`, `PrebidInstreamVideoAd` | [Video](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/video) |
| Listeners, result codes, failures | [Events & errors](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/events) |
| Ad server handoff, `PrebidMultiformatAd` | [Original API](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/original-api) |
| Logs, the bid event listener, test responses | [Debugging](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/debugging) |
| What differs between Android and iOS | [Platform differences](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/platform-differences) |

---

## Ad Server Integration

The ads above use **Prebid Rendered** (In-App Bidding): Prebid runs the
auction and renders the winner, with no ad server. To make Prebid demand
compete in your ad server instead:

- **Original API**: Prebid only runs the auction and returns targeting
  keywords, which you pass to your ad server request yourself
  (`PrebidBannerAdUnit`, `PrebidInterstitialAdUnit`, `PrebidRewardedAdUnit`,
  `PrebidNativeAdUnit`, `PrebidMultiformatAd`). This package doesn't depend
  on `google_mobile_ads`; see [Original API](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/original-api).
- **GAM rendering, AdMob and MAX**: the companion packages
  [`prebid_mobile_sdk_gam`](https://pub.dev/packages/prebid_mobile_sdk_gam),
  [`prebid_mobile_sdk_admob`](https://pub.dev/packages/prebid_mobile_sdk_admob)
  and [`prebid_mobile_sdk_max`](https://pub.dev/packages/prebid_mobile_sdk_max)
  wrap Prebid's event handlers and mediation adapters. They are separate
  packages because they bundle the ad server SDKs natively, so In-App-only
  apps stay lean. See [Choosing an integration](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/integrations).

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

// 1. Run the Prebid auction (Original API: keywords only, no rendering).
final response = await PrebidBannerAdUnit(
  configId: 'your-config-id',
  sizes: const [Size(300, 250)],
).fetchDemand();

// 2. Hand the winning keywords to Google Ad Manager, which renders the winner.
await AdManagerBannerAd(
  adUnitId: '/1234567/your-gam-ad-unit',
  sizes: [AdSize(width: 300, height: 250)],
  request: AdManagerAdRequest(
    customTargeting: response.targetingKeywords ?? const {},
  ),
  listener: AdManagerBannerAdListener(),
).load();
```

---

## Example App

The `example/` directory contains a full-featured demo app including:

- **90+ test cases** across Banner, MRAID, Interstitial, Rewarded, Native, In-Stream Video and Multiformat for In-App, GAM rendering, GAM Original API, AdMob and MAX — mirroring Prebid's `PrebidInternalTestApp`
- **Every callback per test case**: counters, a timestamped event log and the last bid response
- **Fullscreen controls dialog** and banner controller (load / stop refresh)
- **Bid Inspector** showing each bid request / response (`PrebidMobile.setEventListener`)
- **Settings** for every SDK option (timeouts, bidding flags, EIDs placement, SharedID, privacy), applied at startup
- **Targeting data page** for keywords, ext data, OpenRTB config, OMID partner and location

```bash
cd example
flutter pub get
flutter run
```

See [example/README.md](https://github.com/thanhhaidev/prebid-mobile-flutter/tree/main/example/README.md) for detailed documentation.

---

## Contributing

Contributions are welcome: see [CONTRIBUTING.md](https://github.com/thanhhaidev/prebid-mobile-flutter/blob/main/CONTRIBUTING.md) and the [Code of Conduct](https://github.com/thanhhaidev/prebid-mobile-flutter/blob/main/CODE_OF_CONDUCT.md).

---

## License

[MIT License](LICENSE)
