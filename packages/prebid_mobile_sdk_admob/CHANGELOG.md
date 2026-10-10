# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the package uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-10

First stable release: Prebid demand in Google AdMob mediation through Prebid's
AdMob adapters. Built on Prebid Mobile SDK 3.4; requires `prebid_mobile_sdk`
1.0.0.

### Added

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
  banner, interstitial and rewarded ads, and native request options
  (placement count, sequence, URL support, privacy, `ext`; OpenRTB
  configuration on iOS).