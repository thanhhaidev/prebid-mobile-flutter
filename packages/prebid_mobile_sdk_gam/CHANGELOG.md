## 1.0.0 - 2026-10-10

* Initial release: Google Ad Manager rendering for `prebid_mobile_sdk`.
* `PrebidGamBannerAd` — GAM-rendered banner (Android + iOS) with dynamic sizing.
* `PrebidGamInterstitialAd` — GAM-rendered interstitial (Android + iOS).
* `PrebidGamRewardedAd` — GAM-rendered rewarded (Android + iOS).
* Banner / interstitial / rewarded: `customTargeting` for the GAM request (Prebid 3.4 `adManagerRequestConfiguration`) and `onAdExpired`.
* Banner: `PrebidBannerAdController` (`loadAd` / `stopRefresh`), `videoPlacementType` and `PrebidBannerVideoListener` video events;
  auto-refresh only when `refreshIntervalSeconds` > 0.
* Banner: `additionalSizes` (multisize, passed to the GAM event handler), `adFormats`
  (banner + video multiformat), `pbAdSlot`, `impOrtbConfig` and `videoParameters` (iOS only).
* Interstitial / rewarded: `PrebidFullscreenControls` (incl. iOS `supportSKOverlay`) and
  `videoParameters` (sent in the request on iOS; on Android `maxDuration` only caps the rendered video); rewarded passes the
  reward `ext`.
* `PrebidGamNativeAd` — GAM Original-API native (Android + iOS): custom-template
  (`customFormatId`) + unified flow, Prebid creative extracted via `findNative`.
  Events via `PrebidGamNativeAdListener` (incl. `onAdExpired`). Request `assets` /
  `eventTrackers` are configurable.
* Interstitial / rewarded take `impOrtbConfig`; the banner takes `adPosition`; native takes `context` / `contextSubType` / `placementType`. Set the GPID or Prebid ad slot of fullscreen units through `impOrtbConfig` (`ext.gpid`, `ext.data.pbadslot`).
* Android: the banner reports the size of the creative on screen when GAM's own ad wins (multisize slots resize correctly); custom-template native ads are destroyed with their view.
* Banner widgets re-attach a swapped `PrebidBannerAdController` and recreate the native view when their configuration changes.
* Built on Prebid native SDKs Android `3.4.0` / iOS `3.4.1` (iOS 15.0+).
