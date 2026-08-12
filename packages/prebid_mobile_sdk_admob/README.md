# prebid_mobile_sdk_admob

Google **AdMob mediation** for the [`prebid_mobile_sdk`](../) Flutter plugin, via
Prebid's AdMob adapters.

Prebid demand competes inside the **Google AdMob mediation waterfall**: Prebid's
`MediationBannerAdUnit` / `MediationInterstitialAdUnit` run the auction and hand
the winning bid to the AdMob ad object through the Prebid AdMob adapter, and
AdMob renders either the Prebid creative or a competing AdMob creative. This
differs from:

- **Core `prebid_mobile_sdk` (In-App / Prebid Rendered)** — the Prebid SDK
  renders the ad itself.
- **`prebid_mobile_sdk_gam`** — Google Ad Manager renders via Prebid's GAM event
  handlers (line-item integration, not mediation).

This is a **separate package** because it bundles the Google Mobile Ads SDK
natively. Apps that only use Prebid In-App rendering should not depend on it.

## Install

```yaml
dependencies:
  prebid_mobile_sdk: ^0.0.1
  prebid_mobile_sdk_admob: ^0.0.1
```

### Native configuration (required)

The Google Mobile Ads SDK requires an AdMob app ID or the app crashes at
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

In the AdMob dashboard, add Prebid as a mediation / custom-event source on your
ad units and wire the Prebid adapters, per the
[Prebid AdMob integration docs](https://docs.prebid.org/prebid-mobile/modules/rendering/ios-sdk-integration-admob.html).

## Usage

### Banner

```dart
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';

PrebidAdMobBannerAd(
  configId: 'prebid-demo-banner-320-50',
  adMobAdUnitId: 'ca-app-pub-3940256099942544/6300978111',
  width: 320,
  height: 50,
  listener: PrebidBannerAdListener(
    onAdLoaded: () => debugPrint('AdMob banner loaded'),
  ),
);
```

### Interstitial

```dart
final interstitial = PrebidAdMobInterstitialAd(
  configId: 'prebid-demo-display-interstitial-320-480',
  adMobAdUnitId: 'ca-app-pub-3940256099942544/1033173712',
  listener: PrebidInterstitialAdListener(
    onAdLoaded: () => interstitial.show(),
    onAdClosed: () => interstitial.destroy(),
  ),
);
await interstitial.loadAd();
```

`PrebidBannerAdListener` and `PrebidInterstitialAdListener` are re-used from the
core `prebid_mobile_sdk` package.

## API

| Class | Description |
|---|---|
| `PrebidAdMobBannerAd` | Banner widget; AdMob renders. Resizes to the rendered creative. |
| `PrebidAdMobInterstitialAd` | Interstitial controller with `loadAd()` / `show()` / `destroy()`. |

## License

[Apache License 2.0](../LICENSE)
