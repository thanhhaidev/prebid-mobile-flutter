# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the package uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-10

First stable release: Prebid demand in AppLovin MAX mediation through Prebid's
MAX adapters. Built on Prebid Mobile SDK 3.4; requires `prebid_mobile_sdk`
1.0.0 and an initialized AppLovin SDK.

### Added

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
  banner, interstitial and rewarded ads, and native request options
  (placement count, sequence, URL support, privacy, `ext`, OpenRTB
  configuration).