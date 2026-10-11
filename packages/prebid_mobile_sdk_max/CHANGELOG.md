# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the package uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-10-11

### Added

- `gpid` (`imp.ext.gpid`) on every MAX ad, and `pbAdSlot` on
  `PrebidMaxNativeAd`.
- `PrebidMaxPreloadedBannerAd(adaptiveWidth: ...)`: the width an adaptive
  banner spans, apart from `width`, the Prebid request size.

### Changed

- Requires `prebid_mobile_sdk` 1.1.0 or later.

### Fixed

- iOS: `loadAd()` after `stopRefresh()` loads the banner again; it did
  nothing, with no event, because Prebid's mediation unit can't resume once
  stopped. This also applies to preloaded banners.
- iOS: native ads measure their height at the view's width, and again when
  it changes (rotation); text that wraps no longer cuts off the call to
  action.
- Android: interstitial and rewarded ads are released when the Activity is
  destroyed, reporting `onAdFailed`, instead of keeping the Activity alive
  (add-to-app with a cached engine).
- The Android library's Gradle `version` is the package version (it was the
  plugin template's `1.0-SNAPSHOT`).
- Rewarded ads: with several Flutter engines loading the same MAX ad unit,
  which MAX shares per process, the engine that takes the unit over no longer
  has its ad destroyed by the previous owner.

## [1.0.0] - 2026-10-11

First stable release: Prebid demand in AppLovin MAX mediation through Prebid's
MAX adapters. Built on Prebid Mobile SDK 3.4; works with `prebid_mobile_sdk`
1.x (`^1.0.0`) and needs an initialized AppLovin SDK.

### Added

- Preloaded banners (`PrebidMaxPreloadedBannerAd`, shown by `PrebidMaxPreloadedBannerAdView`): loaded
  before their slot is on screen and kept across the views showing them.
- Banner (including 300x250 MREC), interstitial, rewarded and native ads
  mediated by MAX, with MAX's impression events.
- Banners that resize to the rendered creative and can load on demand.
- Rendering controls and video signals for interstitial and rewarded ads;
  one rewarded ad per MAX ad unit, as MAX shares the rewarded ad object.
- Native ads rendered in MAX's native ad view, with configurable assets
  (including image MIME types and `ext` fields) and context.
- Ad position and per-impression OpenRTB configuration, including the GPID.
- Prebid banner auto-refresh (`refreshIntervalSeconds`, off by default on both
  platforms), adaptive banners (`adaptive`) and extra Prebid request sizes
  (`additionalSizes`).
- Multiformat interstitials (`adFormats`).
- Banner `adFormats` (outstream video and multiformat banners) and
  `videoParameters` (iOS only; Android's mediation banner has no
  video-parameters setter and sends the SDK's defaults).
- MAX listeners with revenue events (`onAdRevenuePaid`) and, on banners,
  expand, collapse and display-failure events.
- `PrebidMax.debugDropBidProbability`, a testing-only hook that withholds the
  Prebid bid from MAX to exercise the adapter fallback.
- On Android, a load before the Prebid SDK finishes initializing reports
  `onAdFailed` ("The Prebid SDK is not initialized") on every format, instead
  of never completing (Prebid Android drops such requests silently, so the
  MAX waterfall never ran).
- Interstitials and rewarded ads left from before a hot restart are released.

- Prebid ad slot (`pbAdSlot`) and per-unit global OpenRTB configuration on
  banner, interstitial and rewarded ads, and the native request as
  the core's `NativeParameters` (placement count, sequence, URL support,
  privacy, `ext`, OpenRTB configuration).