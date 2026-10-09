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
  - `setAuctionSettingsId()` — request-level stored auction settings
  - `setEventListener()` — receive every Prebid Server bid request / response as JSON (`PrebidEventDelegate`)
  - `setSendSharedId()`, `getSharedId()`, `resetSharedId()` — Prebid's first-party SharedID
  - `isSdkInitialized`
- **External User IDs** — Third-party identity module support, incl. OpenRTB 2.6 `inserter` / `matcher` / `mm`
  - `ExternalUserId` class with `source`, `identifier`, `atype`, and `ext`
  - `setExternalUserIds()`, `getExternalUserIds()`, `clearExternalUserIds()`
  - Supports UID2, SharedID, LiveRamp, Criteo, NetID, and any OpenRTB-compliant source
- **Ad Formats**
  - **Banner Ads** (`PrebidBannerAd`) — Native PlatformView widget with Display and Video support (multiformat via `adFormats`), auto-refresh via `refreshIntervalSeconds` (off by default on both platforms), `PrebidBannerAdController` (`loadAd` / `stopRefresh`), `pbAdSlot`, `impOrtbConfig`, `videoPlacementType`, and outstream video events via `PrebidBannerVideoListener` (completed / paused / resumed / muted / unmuted)
  - **Interstitial Ads** (`PrebidInterstitialAd`) — Fullscreen modal ads with optional `VideoParameters`, `impOrtbConfig` and `PrebidFullscreenControls` (close / skip button area and position, skip delay, mute, sound button, auto-close, minimum size)
  - **Rewarded Ads** (`PrebidRewardedAd`) — Fullscreen ads with typed `PrebidReward` callbacks (incl. `ext`), `impOrtbConfig` and `PrebidFullscreenControls`
  - **Native Ads** (`PrebidNativeAd`) — Load native ads (Title, Image, Icon, Sponsored, Description, CTA); show them with `PrebidNativeAdView`, which renders natively and registers the view so Prebid tracks impressions and clicks (`onAdImpression`, `onAdClicked`, `onAdExpired`); `pbAdSlot`, `gpid`, `impOrtbConfig`
  - **Multiformat Ads** (`PrebidMultiformatAd`) — Fetch demand across banner, video, and native in a single request; `gpid`; result exposes `exp` and `topBidFiltered`
  - **In-Stream Video** (`PrebidInstreamVideoAd`) — Fetch VAST video demand; result exposes `exp`
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
  - OM SDK partner: `setOmidPartnerName()`, `setOmidPartnerVersion()`
  - Location: `setUserLatLng()`, `setLocationPrecision()`
- **Error Handling**
  - `PrebidException` with typed `PrebidErrorCode` (`initializationFailed`, `adLoadFailed`, `timeout`, etc.)
- **Fullscreen lifecycle** — reloading an interstitial / rewarded replaces the previous ad; `show()` presents from the top-most view controller and reports `onAdFailed` when the ad isn't loaded or can't be presented; native-side errors reach the caller's `Future`
- **Ad expiration** (Prebid 3.4) — `onAdExpired` on banner, interstitial, rewarded and native listeners when the bid's `exp` elapses
- **Mediation impressions** — `onAdImpression` on the banner / interstitial / rewarded listeners, fired by the AdMob and MAX companion packages
- **Companion helpers** — `NativeAsset.toMap()`, `NativeEventTracker.toMap()`, `PrebidFullscreenControls.toMap()` and `PrebidBannerAdController.attachChannel()` used by the GAM / AdMob / MAX packages
- **Infrastructure**
  - **Android** — Prebid Mobile SDK `3.4.0` via Maven
  - **iOS** — PrebidMobile `3.4.1+` via CocoaPods / SPM (iOS 15.0+)
  - Pigeon-based code generation for Dart, Kotlin, and Swift
- **Testing**
  - Unit tests via Mockito covering SDK, targeting, and all ad format classes
- **Example App**
  - 90+ test cases mirroring Prebid's internal test app (In-App, GAM rendering, GAM Original API, AdMob, MAX)
  - Every callback per test case (counters + timestamped event log), fullscreen controls dialog, banner controller
  - Bid Inspector (request / response JSON via `setEventListener`), app log, SDK settings, targeting data
- **CI/CD**
  - Automated GitHub Actions pipeline for formatting, analysis, testing, and multi-platform builds
