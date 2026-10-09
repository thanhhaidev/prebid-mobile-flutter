# prebid_mobile_sdk_max

> **Unofficial project.** This is an independent, community-maintained
> Flutter wrapper around the official
> [Prebid Mobile SDKs](https://docs.prebid.org/prebid-mobile/prebid-mobile-getting-started.html).
> It is not affiliated with, endorsed by, or maintained by Prebid.org. Report
> issues with this plugin in [its repository](https://github.com/thanhhaidev/prebid-mobile-flutter/issues),
> not to Prebid.

AppLovin **MAX mediation** for the [`prebid_mobile_sdk`](https://pub.dev/packages/prebid_mobile_sdk) Flutter plugin, via
Prebid's MAX adapters.

**Documentation:** [thanhhaidev.github.io/prebid-mobile-flutter](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/max)

Prebid demand competes inside the **AppLovin MAX mediation waterfall**: Prebid's
`MediationBannerAdUnit` / `MediationInterstitialAdUnit` run the auction and hand
the winning bid to the MAX ad object through the Prebid MAX adapter, and MAX
renders either the Prebid creative or a competing MAX creative. This differs
from:

- **Core `prebid_mobile_sdk` (In-App / Prebid Rendered)** — the Prebid SDK
  renders the ad itself.
- **`prebid_mobile_sdk_gam`** — Google Ad Manager renders via Prebid's GAM event
  handlers.

This is a **separate package** because it bundles the AppLovin MAX SDK natively.
Apps that only use Prebid In-App rendering should not depend on it.

## Install

```yaml
dependencies:
  prebid_mobile_sdk: ^1.0.0
  prebid_mobile_sdk_max: ^1.0.0
```

### Native configuration (required)

Initialize the AppLovin MAX SDK once at startup with your SDK key **before**
loading any ad here — e.g. via the
[`applovin_max`](https://pub.dev/packages/applovin_max) package:

```dart
await AppLovinMAX.initialize('YOUR_APPLOVIN_SDK_KEY');
```

Declare the SDK key natively as AppLovin requires:

- **iOS** — `AppLovinSdkKey` in `ios/Runner/Info.plist`.
- **Android** — the `applovin.sdk.key` `<meta-data>` in `AndroidManifest.xml`.

In the AppLovin MAX dashboard, add Prebid as a custom network on your ad units
and wire the Prebid MAX adapter, per the
[Prebid MAX integration docs](https://docs.prebid.org/prebid-mobile/modules/rendering/ios-sdk-integration-max.html).

## Compatibility

<!-- compatibility:start -->
<!-- Generated from website/src/data/compatibility.json by website/scripts/sync-compatibility.mjs. Do not edit. -->

| prebid_mobile_sdk_max | Prebid Android (`prebid-mobile-sdk-max-adapters`) | Prebid iOS (`PrebidMobileMAXAdapters`) | AppLovin MAX Android | AppLovin MAX iOS |
| --- | --- | --- | --- | --- |
| 1.0.0 | `3.4.0` | `>= 3.4.1, < 4.0` | `applovin-sdk 13.1.0` | `AppLovinSDK >= 13.0.0` |

Also requires the matching core `prebid_mobile_sdk` release. Android resolves exactly the listed Prebid version. On iOS, CocoaPods and Swift Package Manager pick the newest PrebidMobile release in the range, so a fresh `pod install` can resolve a newer 3.x patch.

Full mapping: [Compatibility](https://thanhhaidev.github.io/prebid-mobile-flutter/docs/compatibility).

<!-- compatibility:end -->

## Usage

### Banner

```dart
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

PrebidMaxBannerAd(
  configId: 'prebid-demo-banner-320-50',
  maxAdUnitId: 'YOUR_MAX_BANNER_AD_UNIT_ID',
  width: 320,
  height: 50,
  listener: PrebidBannerAdListener(
    onAdLoaded: () => debugPrint('MAX banner loaded'),
  ),
);
```

### Interstitial

```dart
final interstitial = PrebidMaxInterstitialAd(
  configId: 'prebid-demo-display-interstitial-320-480',
  maxAdUnitId: 'YOUR_MAX_INTERSTITIAL_AD_UNIT_ID',
  listener: PrebidInterstitialAdListener(
    onAdLoaded: () => interstitial.show(),
    onAdClosed: () => interstitial.destroy(),
  ),
);
await interstitial.loadAd();
```

### Rewarded

```dart
final rewarded = PrebidMaxRewardedAd(
  configId: 'prebid-demo-video-rewarded-320-480',
  maxAdUnitId: 'YOUR_MAX_REWARDED_AD_UNIT_ID',
  listener: PrebidRewardedAdListener(
    onAdLoaded: () => rewarded.show(),
    onUserEarnedReward: (reward) => debugPrint('${reward.count} ${reward.type}'),
    onAdClosed: () => rewarded.destroy(),
  ),
);
await rewarded.loadAd();
```

MAX shares one rewarded ad object per ad unit, so only one
`PrebidMaxRewardedAd` per `maxAdUnitId` is active at a time: loading another
on the same unit takes it over and the previous one receives `onAdFailed`
("Replaced by another ad on the same MAX ad unit").

### Native

```dart
PrebidMaxNativeAd(
  configId: 'prebid-demo-banner-native-styles',
  maxAdUnitId: 'YOUR_MAX_NATIVE_AD_UNIT_ID',
  listener: PrebidMaxNativeAdListener(
    onAdLoaded: () => debugPrint('native loaded'),
    onAdImpression: () => debugPrint('impression'),
  ),
);
```

Rendered through MAX's native ad view so impressions and clicks track. Pass
`assets` / `eventTrackers` to change the requested native assets.

`onAdImpression` (banner, interstitial, rewarded, native) is reported from
MAX's revenue callback, which MAX fires when it records the impression.

`PrebidMaxBannerAd` takes a `PrebidBannerAdController` from the core package:
with `autoLoad: false`, call `controller.loadAd()` to load on demand;
`controller.stopRefresh()` stops Prebid's bid refresh and MAX's banner auto-refresh.

`show()` on an interstitial / rewarded ad that is not loaded yet, or when no
foreground Activity / view controller is available, reports `onAdFailed`
instead of failing silently; `isLoaded` turns false after `show()`,
`onAdClosed` and `onAdFailed`.

> **AppLovin SDK initialization:** MAX only loads ads after the AppLovin SDK is
> initialized with your SDK key. This package does not initialize it; do it at
> startup (for example with the `applovin_max` package) before loading ads.

`PrebidBannerAdListener`, `PrebidInterstitialAdListener`,
`PrebidRewardedAdListener`, `PrebidFullscreenControls`, `NativeAsset` and
`NativeEventTracker` come from the core
[`prebid_mobile_sdk`](https://pub.dev/packages/prebid_mobile_sdk) package.

### Fullscreen controls

Interstitial and rewarded ads accept Prebid's rendering controls (close / skip
button area and position, skip delay, mute, sound button, minimum size):

```dart
controls: const PrebidFullscreenControls(
  closeButtonPosition: PrebidButtonPosition.topLeft,
  skipDelay: 5,
  isMuted: true,
),
```

Skip controls apply to interstitials (and to rewarded on Android only);
`isAutoCloseOnCompletionEnabled` is iOS only. `supportSKOverlay` does not
apply to mediation: Prebid's mediation ad units have no SKOverlay setting, so
it is ignored.

### Video parameters

Interstitial and rewarded ads take `videoParameters` (the core
`VideoParameters`: mimes, protocols, playback methods, `plcmt`, start delay,
linearity, skippable, `battr`, bitrates, durations, API frameworks):

```dart
videoParameters: const VideoParameters(
  mimes: ['video/mp4'],
  plcmt: VideoPlcmt.interstitial,
  maxDuration: 30,
),
```

iOS sends every field from the mediation ad unit. Prebid Android's mediation
interstitial / rewarded ad units only expose `setMaxVideoDuration`, which caps
the rendered video's length but isn't sent in the request.

## API

| Class | Description |
|---|---|
| `PrebidMaxBannerAd` | Banner widget; MAX renders. Resizes to the rendered creative. `PrebidBannerAdController`; `adPosition`, `impOrtbConfig`. |
| `PrebidMaxInterstitialAd` | Interstitial with `loadAd()` / `show()` / `destroy()`, `isVideo`, `controls`, `videoParameters`, `impOrtbConfig`. |
| `PrebidMaxRewardedAd` | Rewarded with `loadAd()` / `show()` / `destroy()`, `controls`, `videoParameters`, `impOrtbConfig`. |
| `PrebidMaxNativeAd` | Native widget rendered via MAX's native ad view; `PrebidMaxNativeAdListener`; `context` / `contextSubType` / `placementType`. |

## License

[Apache License 2.0](LICENSE)
