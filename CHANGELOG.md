# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-03-22

Initial release of the `prebid_mobile_flutter` plugin.

### Added

- **Core SDK** — `PrebidMobile` class for SDK initialization and configuration
  - `initializeSdk()` with Prebid Server URL and account ID
  - Configuration: timeout, geo location, debug mode, log level
  - Custom headers, stored auction/bid responses
  - Creative factory timeout settings
- **Ad Formats**
  - **Banner Ads** (`PrebidBannerAd`) — Native PlatformView widget supporting both Display and Video.
  - **Interstitial Ads** (`PrebidInterstitialAd`) — Fullscreen modal ads.
  - **Rewarded Ads** (`PrebidRewardedAd`) — Fullscreen ads with custom Reward callbacks.
  - **Native Ads** (`PrebidNativeAd`) — Fetch raw native assets (Title, Image, Icon, Sponsored, Description, CTA) and build custom Flutter UIs.
  - **Multiformat Ads** (`PrebidMultiformatAd`) — Fetch demand across multiple formats on a single ad unit.
- **Targeting & Privacy** — `PrebidTargeting` class
  - GDPR: subject flag, consent string
  - COPPA: subject flag
  - TCFv2: purpose consents, device access consent
  - ExtData: User keywords, app keywords, App ext data (first-party data)
  - Global OpenRTB configuration
  - App info: content URL, publisher name, store URL, domain
- **Error Handling**
  - Robust exception handling via `PrebidException` encapsulating Android/iOS native errors with typed `PrebidErrorCode`.
- **Infrastructure**
  - **Android support** — Wrapped Prebid Mobile SDK `3.3.0` via Maven.
  - **iOS support** — Wrapped PrebidMobile `~> 3.1` via CocoaPods.
  - Implemented automatic code generation across Dart, Kotlin, and Swift using pigeon.
- **Example App**
  - Comprehensive demo mirroring the native Prebid iOS demo app.
  - Contains test cases for all formats.
  - Built-in Console Logger and Settings Manager.
  - Built-in Targeting Data Manager.
- **CI/CD**
  - Automated GitHub Actions pipeline for linting, testing, and multi-platform compilation.
