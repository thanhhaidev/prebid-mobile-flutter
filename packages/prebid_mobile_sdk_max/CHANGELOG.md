## 1.0.0 - 2026-10-10

* Initial release: AppLovin MAX mediation for `prebid_mobile_sdk`.
* `PrebidMaxBannerAd` — MAX-mediated banner (Android + iOS) with dynamic sizing and
  `PrebidBannerAdController` (`loadAd` / `stopRefresh`).
* `PrebidMaxInterstitialAd` — MAX-mediated interstitial (Android + iOS).
* `PrebidMaxRewardedAd` — MAX-mediated rewarded (Android + iOS) with reward callback; one active
  ad per MAX ad unit (MAX shares the rewarded instance).
* `PrebidMaxNativeAd` — MAX-mediated native (Android + iOS), rendered via the SDK native ad view.
  Events via `PrebidMaxNativeAdListener`; request `assets` / `eventTrackers` are configurable.
* Banner / interstitial / rewarded / native report `onAdImpression` (from MAX's revenue callback);
  interstitial / rewarded accept `PrebidFullscreenControls` (`supportSKOverlay` has no mediation
  equivalent and is ignored).
* Interstitial / rewarded: `videoParameters` (sent in the request on iOS; on Android `maxDuration` only caps the rendered video).
* Banner takes `adPosition` and `impOrtbConfig`; interstitial / rewarded take `impOrtbConfig` (also how to set the GPID: `ext.gpid`); native takes `context` / `contextSubType` / `placementType`.
* Banner: a 300x250 slot loads with MAX's MREC format (MREC ad units are rejected by the banner format).
* Banner widgets re-attach a swapped `PrebidBannerAdController` and recreate the native view when their configuration changes.
* Built on Prebid native SDKs Android `3.4.0` / iOS `3.4.1` (iOS 15.0+).
