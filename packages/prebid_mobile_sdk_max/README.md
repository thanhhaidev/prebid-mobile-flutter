# prebid_mobile_sdk_max

AppLovin **MAX mediation** for the [`prebid_mobile_sdk`](../) Flutter plugin, via
Prebid's MAX adapters.

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
  prebid_mobile_sdk: ^0.0.1
  prebid_mobile_sdk_max: ^0.0.1
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

`PrebidBannerAdListener` and `PrebidInterstitialAdListener` are re-used from the
core `prebid_mobile_sdk` package.

## API

| Class | Description |
|---|---|
| `PrebidMaxBannerAd` | Banner widget; MAX renders. Resizes to the rendered creative. |
| `PrebidMaxInterstitialAd` | Interstitial controller with `loadAd()` / `show()` / `destroy()`. |

## License

[Apache License 2.0](../LICENSE)
