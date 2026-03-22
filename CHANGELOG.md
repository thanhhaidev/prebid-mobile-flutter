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
  - `getSdkVersion()` to query native SDK version
- **External User IDs** — Third-party identity module support
  - `ExternalUserId` class with `source`, `identifier`, `atype`, and `ext`
  - `setExternalUserIds()`, `getExternalUserIds()`, `clearExternalUserIds()`
  - Supports UID2, SharedID, LiveRamp, Criteo, NetID, and any OpenRTB-compliant source
- **Ad Formats**
  - **Banner Ads** (`PrebidBannerAd`) — Native PlatformView widget with Display and Video support, auto-refresh via `refreshIntervalSeconds`
  - **Interstitial Ads** (`PrebidInterstitialAd`) — Fullscreen modal ads with optional `VideoParameters`
  - **Rewarded Ads** (`PrebidRewardedAd`) — Fullscreen ads with typed `PrebidReward` callbacks
  - **Native Ads** (`PrebidNativeAd`) — Fetch raw native assets (Title, Image, Icon, Sponsored, Description, CTA)
  - **Multiformat Ads** (`PrebidMultiformatAd`) — Fetch demand across banner, video, and native in a single request
  - **In-Stream Video** (`PrebidInstreamVideoAd`) — Fetch VAST video demand
- **Video Parameters** — Full OpenRTB video configuration
  - `VideoParameters` class with `mimes`, `protocols`, `playbackMethods`, `placement`, `maxDuration`, `minDuration`, `api`
  - Typed enums: `VideoProtocol`, `VideoPlaybackMethod`, `VideoPlacement`, `VideoApi`
- **Targeting & Privacy** — `PrebidTargeting` class
  - GDPR: subject flag, consent string
  - COPPA: subject flag
  - TCFv2: purpose consents, device access consent
  - CCPA / US Privacy: `setUSPrivacyString()`, `getUSPrivacyString()`
  - GPP: auto-read from SharedPreferences/UserDefaults (CMP integration)
  - App First-Party Data: keywords, ext data (`app.ext.data`)
  - User First-Party Data: keywords, ext data (`user.ext.data`)
  - Access control list for bidder data access
  - Global OpenRTB configuration
  - App info: content URL, publisher name, store URL, domain
- **Error Handling**
  - `PrebidException` with typed `PrebidErrorCode` (`initializationFailed`, `adLoadFailed`, `timeout`, etc.)
- **Infrastructure**
  - **Android** — Prebid Mobile SDK `3.3.0` via Maven
  - **iOS** — PrebidMobile `~> 3.1` via CocoaPods
  - Pigeon-based code generation for Dart, Kotlin, and Swift
- **Testing**
  - Unit tests via Mockito covering SDK, targeting, and all ad format classes
- **Example App**
  - Comprehensive demo with 30+ test cases
  - Console Logger, Settings Manager, and Targeting Data Manager
- **CI/CD**
  - Automated GitHub Actions pipeline for formatting, analysis, testing, and multi-platform builds
