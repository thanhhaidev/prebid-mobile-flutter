# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the package uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `gpid` (`imp.ext.gpid`) on `PrebidGamBannerAd`,
  `PrebidGamPreloadedBannerAd`, `PrebidGamInterstitialAd` and
  `PrebidGamRewardedAd`, as on `PrebidGamNativeAd`.

### Changed

- Requires `prebid_mobile_sdk` 1.1.0 or later.

### Fixed

- Android: `PrebidGamNativeAd` reports `onFetchDemandFailed('prebidDemandNoBids')`
  when no bid won; Prebid's `hb_cache_id_local` keyword, set either way,
  made it report `onFetchDemandSuccess`.
- A GAM custom-format native ad without a Prebid creative records its
  impression once half of it has been on screen for a second, Flutter's
  clips (a scroll viewport, `ClipRect`) included, instead of as soon as it
  rendered (an ad built off screen counted an impression).
- iOS: native ads measure their height at the view's width, and again when
  it changes (rotation); text that wraps no longer cuts off the bottom of the
  ad. A custom-format ad reports its height too.
- Android: interstitial and rewarded ads are released when the Activity is
  destroyed, reporting `onAdFailed`, instead of keeping the Activity alive
  (add-to-app with a cached engine).
- The Android library's Gradle `version` is the package version (it was the
  plugin template's `1.0-SNAPSHOT`).
- Android: native ads free their `NativeAdView` when replaced or disposed,
  and lay out in dp rather than raw pixels (they looked different on each
  screen density).
- iOS: fullscreen ads present from the Flutter engine's own window, and
  banners from their own, instead of the first key window: on an iPad with
  several windows, or with Flutter in a secondary scene (add-to-app), they
  appeared in the wrong one. The key window remains the fallback.
- iOS: a GAM custom-format ad that wins reports `onAdImpression` and
  `onAdClicked`, as on Android.
- iOS: a native ad's click-through opens from the ad's own window.
- Android: interstitial and rewarded ads are released when the Activity is
  re-created for a configuration change, as the core plugin's are, instead
  of showing on the destroyed Activity.
- `PrebidGamNativeAd` in a parent with an unbounded width (a `Row`, a
  horizontal list) takes the screen width instead of failing layout.
- iOS: `show()` during a view controller transition that UIKit can't queue
  reports `onAdDisplayed` or `onAdFailed`; it could report neither.
- Android: a result code added by a newer Prebid SDK no longer crashes the
  app.

## [1.0.0] - 2026-10-11

First stable release: Google Ad Manager renders Prebid and direct-sold demand
through Prebid's GAM event handlers. Built on Prebid Mobile SDK 3.4; works with
`prebid_mobile_sdk` 1.x (`^1.0.0`).

### Added

- Preloaded banners (`PrebidGamPreloadedBannerAd`, shown by `PrebidGamPreloadedBannerAdView`): loaded
  before their slot is on screen and kept across the views showing them.
- Banner ads with multisize, banner and video multiformat, outstream video
  events, auto-refresh and on-demand loading; the slot resizes to the
  creative that renders.
- Interstitial and rewarded ads with rendering controls and video signals;
  interstitials request display, video (`isVideo`) or both (`adFormats`).
- Native ads through GAM custom native formats and unified native ads, with
  `customTargeting`, `gpid`, `pbAdSlot` and `impOrtbConfig`, and configurable
  assets (including image MIME types and `ext` fields). For a Prebid
  creative, `onAdImpression` fires when Prebid's impression tracker request
  succeeds (the core native view's is viewability-based).
- Custom Google Ad Manager targeting alongside Prebid's keywords.
- Ad position, ad slot, GPID and per-impression OpenRTB configuration.
- Bid expiration events.
- On Android, ads loaded before the Prebid SDK finished initializing report
  `onAdFailed` ("The Prebid SDK is not initialized"; native:
  `onFetchDemandFailed('prebidSdkNotInitialized')`) instead of never
  answering.
- Prebid ad slot (`pbAdSlot`) on interstitial and rewarded ads, per-unit
  global OpenRTB configuration on every format, and the native request as
  the core's `NativeParameters` (placement count, sequence, URL support,
  privacy, `ext`).