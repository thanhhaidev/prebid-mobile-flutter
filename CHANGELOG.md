# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-03-21

### Added

- **Core SDK** — `PrebidMobile` class for SDK initialization and configuration
  - `initializeSdk()` with Prebid Server URL and account ID
  - Configuration: timeout, geo location, debug mode, log level
  - Custom headers, stored auction/bid responses
  - Creative factory timeout settings
- **Banner Ads** — `PrebidBannerAd` widget using native PlatformView
  - Supports display and video banner formats
  - Auto-load option
  - Event callbacks: loaded, failed, clicked, closed
- **Interstitial Ads** — `PrebidInterstitialAd` with load/show/destroy lifecycle
  - Supports banner and video ad formats
  - Event callbacks: loaded, failed, displayed, dismissed, clicked
- **Rewarded Ads** — `PrebidRewardedAd` with load/show/destroy lifecycle
  - Reward callback with type, count, and ext data
  - Event callbacks: loaded, failed, displayed, dismissed, clicked
- **Targeting & Privacy** — `PrebidTargeting` class
  - GDPR: subject flag, consent string
  - COPPA: subject flag
  - TCFv2: purpose consents, device access consent
  - User keywords, app keywords
  - App ext data (first party data)
  - Access control list for bidders
  - Global OpenRTB configuration
  - App info: content URL, publisher name, store URL, domain
- **Error Handling** — `PrebidException` with typed `PrebidErrorCode`
- **Android support** — Prebid Mobile SDK 3.3.0 via Maven
- **iOS support** — PrebidMobile ~> 3.1 via CocoaPods
- **Example app** — Demonstrates all ad types with Prebid test config IDs
- **Unit tests** — 14 tests covering models, enums, exceptions, and listeners
