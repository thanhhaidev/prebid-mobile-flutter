## 0.0.1

* Initial release: Google Ad Manager rendering for `prebid_mobile_sdk`.
* `PrebidGamBannerAd` — GAM-rendered banner (Android + iOS) with dynamic sizing.
* `PrebidGamInterstitialAd` — GAM-rendered interstitial (Android + iOS).
* `PrebidGamRewardedAd` — GAM-rendered rewarded (Android + iOS).
* Banner / interstitial / rewarded: `customTargeting` for the GAM request (Prebid 3.4 `adManagerRequestConfiguration`) and `onAdExpired`.
* `PrebidGamNativeAd` — GAM Original-API native (Android + iOS): custom-template
  (`customFormatId`) + unified flow, Prebid creative extracted via `findNative`.
  Events via `PrebidGamNativeAdListener`.
* Built on Prebid native SDKs Android `3.4.0` / iOS `3.4.1` (iOS 15.0+).
