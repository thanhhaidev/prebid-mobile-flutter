## 0.0.1

* Initial release: AppLovin MAX mediation for `prebid_mobile_sdk`.
* `PrebidMaxBannerAd` — MAX-mediated banner (Android + iOS) with dynamic sizing.
* `PrebidMaxInterstitialAd` — MAX-mediated interstitial (Android + iOS).
* `PrebidMaxRewardedAd` — MAX-mediated rewarded (Android + iOS) with reward callback.
* `PrebidMaxNativeAd` — MAX-mediated native (Android + iOS), rendered via the SDK native ad view.
  Events via `PrebidMaxNativeAdListener`; request `assets` / `eventTrackers` are configurable.
* Banner / interstitial / rewarded / native report `onAdImpression` (from MAX's revenue callback);
  interstitial / rewarded accept `PrebidFullscreenControls`.
* Built on Prebid native SDKs Android `3.4.0` / iOS `3.4.1` (iOS 15.0+).
