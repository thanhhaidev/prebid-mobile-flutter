## 0.0.1

* Initial release: Google AdMob mediation for `prebid_mobile_sdk`.
* `PrebidAdMobBannerAd` — AdMob-mediated banner (Android + iOS) with dynamic sizing and
  `PrebidBannerAdController` (`loadAd` / `stopRefresh`).
* `PrebidAdMobInterstitialAd` — AdMob-mediated interstitial (Android + iOS).
* `PrebidAdMobRewardedAd` — AdMob-mediated rewarded (Android + iOS) with reward callback.
* `PrebidAdMobNativeAd` — AdMob-mediated native (Android + iOS), rendered via the SDK
  native ad view (incl. media view). Events via `PrebidAdMobNativeAdListener`.
  Request `assets` / `eventTrackers` are configurable.
* Banner / interstitial / rewarded report `onAdImpression`; interstitial / rewarded accept
  `PrebidFullscreenControls` (`supportSKOverlay` has no mediation equivalent and is ignored).
* Interstitial / rewarded: `videoParameters` (sent in the request on iOS; on Android `maxDuration` only caps the rendered video).
* Banner takes `adPosition` and `impOrtbConfig`; interstitial / rewarded take `impOrtbConfig` (also how to set the GPID: `ext.gpid`); native takes `context` / `contextSubType` / `placementType`.
* Built on Prebid native SDKs Android `3.4.0` / iOS `3.4.1` (iOS 15.0+).
