# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the package uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-10

First stable release: Google Ad Manager renders Prebid and direct-sold demand
through Prebid's GAM event handlers. Built on Prebid Mobile SDK 3.4; requires
`prebid_mobile_sdk` 1.0.0.

### Added

- Banner ads with multisize, banner and video multiformat, outstream video
  events, auto-refresh and on-demand loading; the slot resizes to the
  creative that renders.
- Interstitial and rewarded ads with rendering controls and video signals;
  interstitials request display, video (`isVideo`) or both (`adFormats`).
- Native ads through GAM custom native formats and unified native ads, with
  `customTargeting`, `gpid`, `pbAdSlot` and `impOrtbConfig`. For a Prebid
  creative, `onAdImpression` fires when Prebid's impression tracker request
  succeeds (the core native view's is viewability-based).
- Custom Google Ad Manager targeting alongside Prebid's keywords.
- Ad position, ad slot, GPID and per-impression OpenRTB configuration.
- Bid expiration events.
- On Android, ads loaded before the Prebid SDK finished initializing report
  `onAdFailed` ("The Prebid SDK is not initialized"; native:
  `onFetchDemandFailed('prebidSdkNotInitialized')`) instead of never
  answering.
