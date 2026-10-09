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
- Native ads rendered in AdMob's native ad view, with configurable assets and
  context.
- Ad position and per-impression OpenRTB configuration, including the GPID.
