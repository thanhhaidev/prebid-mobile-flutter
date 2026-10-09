# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-03-22

Initial release of the `prebid_mobile_sdk` plugin.

### Added

- **Core SDK** — `PrebidMobile` class for SDK initialization and configuration
  - `initializeSdk()` with Prebid Server URL and account ID
  - Configuration: timeout, geo location, debug mode, log level
  - Custom headers, stored auction/bid responses
  - Creative factory timeout settings
  - `getSdkVersion()` to query native SDK version
  - `setShouldAssignNativeAssetId()` — sequential native asset IDs (needed when a creative references assets by ID)
  - `setFilterOutUncachedBids()` — drop bids without a Prebid Cache entry (Prebid 3.4; `topBidFiltered` / `prebidDemandNoCachedBids`)
  - `setEidsPlacement()` — send EIDs in `user.eids` (OpenRTB 2.6), `user.ext.eids` (2.5) or both
  - `setIncludeWinners()` / `setIncludeBidderKeys()` — Prebid Server targeting flags
- **External User IDs** — Third-party identity module support, incl. OpenRTB 2.6 `inserter` / `matcher` / `mm`
  - `ExternalUserId` class with `source`, `identifier`, `atype`, and `ext`
  - `setExternalUserIds()`, `getExternalUserIds()`, `clearExternalUserIds()`
  - Supports UID2, SharedID, LiveRamp, Criteo, NetID, and any OpenRTB-compliant source
- **Ad Formats**
  - **Banner Ads** (`PrebidBannerAd`) — Native PlatformView widget with Display and Video support (multiformat via `adFormats`), auto-refresh via `refreshIntervalSeconds`, `PrebidBannerAdController` (`loadAd` / `stopRefresh`), `pbAdSlot`, `impOrtbConfig`
  - **Interstitial Ads** (`PrebidInterstitialAd`) — Fullscreen modal ads with optional `VideoParameters` and `impOrtbConfig`
  - **Rewarded Ads** (`PrebidRewardedAd`) — Fullscreen ads with typed `PrebidReward` callbacks and `impOrtbConfig`
  - **Native Ads** (`PrebidNativeAd`) — Load native ads (Title, Image, Icon, Sponsored, Description, CTA); show them with `PrebidNativeAdView`, which renders natively and registers the view so Prebid tracks impressions and clicks (`onAdImpression`, `onAdClicked`, `onAdExpired`); `pbAdSlot`, `gpid`, `impOrtbConfig`
  - **Multiformat Ads** (`PrebidMultiformatAd`) — Fetch demand across banner, video, and native in a single request; `gpid`; result exposes `exp` and `topBidFiltered`
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
- **Ad expiration** (Prebid 3.4) — `onAdExpired` on banner, interstitial, rewarded and native listeners when the bid's `exp` elapses
- **Infrastructure**
  - **Android** — Prebid Mobile SDK `3.4.0` via Maven
  - **iOS** — PrebidMobile `3.4.1+` via CocoaPods / SPM (iOS 15.0+)
  - Pigeon-based code generation for Dart, Kotlin, and Swift
- **Testing**
  - Unit tests via Mockito covering SDK, targeting, and all ad format classes
- **Example App**
  - Comprehensive demo with 30+ test cases
  - Console Logger, Settings Manager, and Targeting Data Manager
- **CI/CD**
  - Automated GitHub Actions pipeline for formatting, analysis, testing, and multi-platform builds
