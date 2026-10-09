# prebid_mobile_sdk_gam

Google Ad Manager (GAM) **rendering** for the [`prebid_mobile_sdk`](https://pub.dev/packages/prebid_mobile_sdk) Flutter
plugin, via Prebid's GAM event handlers.

Prebid runs the auction and lets **Google Ad Manager render** the ad: a winning
Prebid bid is served through a GAM line item + the Prebid Universal Creative,
and direct-sold GAM demand competes in the same auction. This differs from:

- **Core `prebid_mobile_sdk` (In-App / Prebid Rendered)** — the Prebid SDK
  renders the ad itself.
- **Original API keyword handoff** — Prebid returns keywords and you pass them
  to `google_mobile_ads` yourself (see the core plugin's
  `PrebidBannerAdUnit` / `PrebidInterstitialAdUnit`).

This is a **separate package** because it bundles the Google Mobile Ads SDK
natively. Apps that only use Prebid In-App rendering should not depend on it and
are not forced to declare a GAM app ID.

## Install

```yaml
dependencies:
  prebid_mobile_sdk: ^0.0.1
  prebid_mobile_sdk_gam: ^0.0.1
```

### Native configuration (required)

The Google Mobile Ads SDK requires a GAM/AdMob app ID or the app crashes at
startup:

- **Android** — in `AndroidManifest.xml`:
  ```xml
  <meta-data
      android:name="com.google.android.gms.ads.APPLICATION_ID"
      android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy" />
  ```
- **iOS** — in `ios/Runner/Info.plist`:
  ```xml
  <key>GADApplicationIdentifier</key>
  <string>ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy</string>
  ```

Initialize the Google Mobile Ads SDK once at startup (e.g. via the
`google_mobile_ads` package):

```dart
await MobileAds.instance.initialize();
```

In Google Ad Manager, configure Prebid line items/creatives that target the
`hb_*` keys so a winning Prebid bid renders.

## Usage

### Banner

```dart
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';

PrebidGamBannerAd(
  configId: 'prebid-demo-banner-320-50',
  gamAdUnitId: '/21808260008/prebid_oxb_320x50_banner',
  width: 320,
  height: 50,
  listener: PrebidBannerAdListener(
    onAdLoaded: () => debugPrint('GAM banner loaded'),
  ),
);
```

### Interstitial

```dart
final interstitial = PrebidGamInterstitialAd(
  configId: 'prebid-demo-display-interstitial-320-480',
  gamAdUnitId: '/21808260008/prebid_oxb_html_interstitial',
  listener: PrebidInterstitialAdListener(
    onAdLoaded: () => interstitial.show(),
    onAdClosed: () => interstitial.destroy(),
  ),
);
await interstitial.loadAd();
```

### Rewarded

```dart
final rewarded = PrebidGamRewardedAd(
  configId: 'prebid-demo-video-rewarded-320-480',
  gamAdUnitId: '/21808260008/prebid_oxb_rewarded_video',
  listener: PrebidRewardedAdListener(
    onAdLoaded: () => rewarded.show(),
    onUserEarnedReward: (reward) => debugPrint('${reward.count} ${reward.type}'),
    onAdClosed: () => rewarded.destroy(),
  ),
);
await rewarded.loadAd();
```

### Native (Original API: custom template + unified)

```dart
PrebidGamNativeAd(
  configId: 'prebid-demo-banner-native-styles',
  gamAdUnitId: '/21808260008/apollo_custom_template_native_ad_unit',
  customFormatId: '11934135',
  listener: PrebidGamNativeAdListener(
    onNativeAdLoaded: () => debugPrint('Prebid native rendered'),
    onPrimaryAdWinUnified: () => debugPrint('GAM native won'),
    onAdImpression: () => debugPrint('impression'),
  ),
);
```

Pass `assets` / `eventTrackers` to change the requested native assets (the
default is title, icon, main image, sponsored, description and call to
action).

### GAM request targeting and banner controls

Banner, interstitial and rewarded take `customTargeting`, added to the GAM
request (Prebid's `hb_*` keys win on conflict). `PrebidGamBannerAd` also takes
a `PrebidBannerAdController` (`loadAd()` with `autoLoad: false`,
`stopRefresh()`), `videoPlacementType` and a `PrebidBannerVideoListener` for
outstream video events. Banner auto-refresh is off unless
`refreshIntervalSeconds` is positive (`null` / `0` disable it on both
platforms).

The banner also mirrors the core `PrebidBannerAd` request options:

| Parameter | Description |
|---|---|
| `additionalSizes` | Extra sizes besides `width` x `height` (multisize). All sizes go to the GAM event handler as valid ad sizes and Prebid requests them all. |
| `adFormats` | `{AdFormat.banner, AdFormat.video}` for a multiformat banner (Prebid 3.4); overrides `isVideo`. |
| `pbAdSlot` | Prebid ad slot (`imp.ext.data.pbadslot`). |
| `impOrtbConfig` | Impression-level OpenRTB JSON merged into the `imp`. |
| `videoParameters` | OpenRTB video parameters for outstream video. **iOS only** — Prebid Android's `BannerView` has no video-parameters setter. |

`show()` on an interstitial / rewarded ad that is not loaded yet, or when no
foreground Activity / view controller is available, reports `onAdFailed`
instead of failing silently; `isLoaded` turns false after `show()`,
`onAdClosed`, `onAdFailed` and `onAdExpired`.

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
`isAutoCloseOnCompletionEnabled` and `supportSKOverlay` (present an SKOverlay
for SKAdNetwork ads) are iOS only.

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

iOS sends every field. Prebid Android's rendering interstitial / rewarded ad
units only expose `setMaxVideoDuration`, which caps the rendered video's length
but isn't sent in the request.

## API

| Class | Description |
|---|---|
| `PrebidGamBannerAd` | Banner widget; GAM renders. Resizes to the rendered creative. `additionalSizes`, `adFormats`, `pbAdSlot`, `impOrtbConfig`, `videoParameters` (iOS), controller, video events, `onAdExpired`. |
| `PrebidGamInterstitialAd` | Interstitial with `loadAd()` / `show()` / `destroy()`, `adFormats`, `controls`, `videoParameters`. |
| `PrebidGamRewardedAd` | Rewarded with `loadAd()` / `show()` / `destroy()`, reward incl. `ext`, `controls`, `videoParameters`. |
| `PrebidGamNativeAd` | Native widget for the GAM Original-API flow; events via `PrebidGamNativeAdListener`. |

## License

[Apache License 2.0](LICENSE)
