# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the package uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `gpid` (`imp.ext.gpid`) on every AdMob ad, and `pbAdSlot` on
  `PrebidAdMobNativeAd`.
- Android: `PrebidAdMobNativeAd` sends `impOrtbConfig` and
  `globalOrtbConfig` (and the `pbAdSlot` and `gpid` in it); they were iOS
  only.
- `PrebidAdMobPreloadedBannerAd(adaptiveWidth: ...)`: the width an adaptive
  banner spans, apart from `width`, the Prebid request size.
- `PrebidAdMobNativeAd(width: ...)`.

### Changed

- Requires `prebid_mobile_sdk` 1.1.0 or later.
- Android: Prebid Mobile SDK 3.4.1 (was 3.4.0).

### Fixed

- iOS: `loadAd()` after `stopRefresh()` loads the banner again; it did
  nothing, with no event, because Prebid's mediation unit can't resume once
  stopped. This also applies to preloaded banners.
- An interstitial or rewarded ad shows once: a second `show()` reports
  `onAdFailed` (not loaded) instead of presenting the used ad again.
- Interstitial and rewarded ads report `onAdExpired` when AdMob's one-hour
  lifetime runs out before they are shown (AdMob has no callback for it);
  `isLoaded` turns false and the ad must be loaded again.
- iOS: native ads measure their height at the view's width, and again when
  it changes (rotation); text that wraps no longer cuts off the call to
  action.
- Android: interstitial and rewarded ads are released when the Activity is
  destroyed, reporting `onAdFailed`, instead of keeping the Activity alive
  (add-to-app with a cached engine).
- The Android library's Gradle `version` is the package version (it was the
  plugin template's `1.0-SNAPSHOT`).
- Android: native ads free their `NativeAdView` when disposed, and lay out
  in dp rather than raw pixels.
- iOS: fullscreen ads present from the Flutter engine's own window, and
  banners from their own, instead of the first key window: on an iPad with
  several windows, or with Flutter in a secondary scene (add-to-app), they
  appeared in the wrong one. The key window remains the fallback.
- `PrebidAdMobNativeAd` in a parent with an unbounded width (a `Row`, a
  horizontal list) takes the screen width instead of failing layout.
- iOS: a native ad's click-through opens from the ad's own window.
- Android: interstitial and rewarded ads are released when the Activity is
  re-created for a configuration change, as the core plugin's are.
- iOS: `show()` during a view controller transition that UIKit can't queue
  reports `onAdDisplayed` or `onAdFailed`; it could report neither.

## [1.0.0] - 2026-10-11

First stable release: Prebid demand in Google AdMob mediation through Prebid's
AdMob adapters. Built on Prebid Mobile SDK 3.4; works with
`prebid_mobile_sdk` 1.x (`^1.0.0`).

### Added

- Preloaded banners (`PrebidAdMobPreloadedBannerAd`, shown by `PrebidAdMobPreloadedBannerAdView`): loaded
  before their slot is on screen and kept across the views showing them.
- Banner, interstitial, rewarded and native ads mediated by AdMob, with
  AdMob's impression events.
- Banners that resize to the rendered creative and can load on demand.
- Rendering controls and video signals for interstitial and rewarded ads.
- Native ads rendered in AdMob's native ad view, with configurable assets
  (including image MIME types and `ext` fields) and context.
- Ad position and per-impression OpenRTB configuration, including the GPID.
- Prebid banner auto-refresh (`refreshIntervalSeconds`, off by default on both
  platforms), adaptive banners (`adaptive`) and extra Prebid request sizes
  (`additionalSizes`).
- Multiformat interstitials (`adFormats`).
- Video and multiformat banners: `adFormats` and `videoParameters` on
  `PrebidAdMobBannerAd` (`videoParameters` applies on iOS; Prebid Android's
  mediation banner has no video setter, so Android sends the SDK's defaults).
- On Android, ads loaded before the Prebid SDK finished initializing report
  `onAdFailed` ("The Prebid SDK is not initialized") instead of never
  finishing: Prebid Android drops such requests, so AdMob's waterfall never
  ran.
- `PrebidAdMob.debugDropBidProbability`, a testing-only hook that drops the
  Prebid bid before AdMob loads to exercise the adapter fallback.
- Prebid ad slot (`pbAdSlot`) and per-unit global OpenRTB configuration on
  banner, interstitial and rewarded ads, and the native request as
  the core's `NativeParameters` (placement count, sequence, URL support,
  privacy, `ext`; OpenRTB configuration on iOS).