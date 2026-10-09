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
  - iOS non-tracking server URL for users who haven't authorized tracking (`initializeSdk(nonTrackingUrl:)`)
  - Creative factory timeout settings
  - `getSdkVersion()` to query native SDK version
  - `setShouldAssignNativeAssetId()` — sequential native asset IDs (needed when a creative references assets by ID)
  - `setFilterOutUncachedBids()` — drop bids without a Prebid Cache entry (Prebid 3.4; `topBidFiltered` / `prebidDemandNoCachedBids`)
  - `setEidsPlacement()` — send EIDs in `user.eids` (OpenRTB 2.6), `user.ext.eids` (2.5) or both
  - `setIncludeWinners()` / `setIncludeBidderKeys()` — Prebid Server targeting flags
  - `setAuctionSettingsId()` — request-level stored auction settings
  - `setDisableStatusCheck()` — skip the Prebid Server status request during init
  - `setEventListener()` — receive every Prebid Server bid request / response as JSON (`PrebidEventDelegate`)
  - `setSendSharedId()`, `getSharedId()`, `resetSharedId()` — Prebid's first-party SharedID
  - `isSdkInitialized`
- **External User IDs** — Third-party identity module support, incl. OpenRTB 2.6 `inserter` / `matcher` / `mm`
  - `ExternalUserId` class with `source`, `identifier`, `atype`, and `ext`
  - `setExternalUserIds()`, `getExternalUserIds()`, `clearExternalUserIds()`
  - Supports UID2, SharedID, LiveRamp, Criteo, NetID, and any OpenRTB-compliant source
- **Ad Formats**
  - **Banner Ads** (`PrebidBannerAd`) — Native PlatformView widget with Display and Video support, multisize via `additionalSizes`, `adPosition`, (iOS) `videoParameters` (multiformat via `adFormats`), auto-refresh via `refreshIntervalSeconds` (off by default on both platforms), `PrebidBannerAdController` (`loadAd` / `stopRefresh`), `pbAdSlot`, `impOrtbConfig`, `videoPlacementType`, and outstream video events via `PrebidBannerVideoListener` (completed / paused / resumed / muted / unmuted)
  - **Interstitial Ads** (`PrebidInterstitialAd`) — Fullscreen modal ads with optional `VideoParameters`, `impOrtbConfig` and `PrebidFullscreenControls` (close / skip button area and position, skip delay, mute, sound button, auto-close, minimum size, iOS `supportSKOverlay`)
  - **Rewarded Ads** (`PrebidRewardedAd`) — Fullscreen ads with typed `PrebidReward` callbacks (incl. `ext`), `impOrtbConfig` and `PrebidFullscreenControls`
  - **Native Ads** (`PrebidNativeAd`) — Load native ads (Title, Image, Icon, Sponsored, Description, CTA, plus every title / image / data asset and the AdChoices `privacyUrl` in `PrebidNativeAdResponse`); show them with `PrebidNativeAdView`, which renders natively and registers the view so Prebid tracks impressions and clicks (`onAdClicked`, `onAdExpired`); `onAdImpression` fires once per ad when the view has been at least half on screen for 1 s (IAB), on both platforms, whether or not Prebid's tracker requests succeed; `pbAdSlot`, `gpid`, `impOrtbConfig`, `contextSubType`
  - **Multiformat Ads** (`PrebidMultiformatAd`) — Fetch demand across banner, video, and native in a single request; `gpid`, `adPosition`, native context / subtype / placement; result exposes `exp` and `topBidFiltered`
  - **Original API units** (`PrebidBannerAdUnit`, `PrebidInterstitialAdUnit`, `PrebidNativeAdUnit`) — auto-refresh (`setAutoRefreshInterval` / `stopAutoRefresh` / `resumeAutoRefresh`, results via `onDemandRefreshed`) and Prebid impression tracking (`activateImpressionTracker()` for banners, `trackImpression` for interstitials)
  - **In-Stream Video** (`PrebidInstreamVideoAd`) — Fetch VAST video demand with `VideoParameters`; result exposes `exp`
- **Video Parameters** — Full OpenRTB video configuration
  - `VideoParameters` class with `mimes`, `protocols`, `playbackMethods`, `placement`, OpenRTB 2.6 `plcmt`, `maxDuration`, `minDuration`, `startDelay`, `linearity`, `skippable`, `battr`, `minBitrate` / `maxBitrate`, `api`
  - Typed enums: `VideoProtocol`, `VideoPlaybackMethod`, `VideoPlacement`, `VideoPlcmt`, `VideoLinearity`, `VideoCreativeAttribute`, `VideoApi`; `VideoStartDelay` constants
- **Targeting & Privacy** — `PrebidTargeting` class
  - GDPR: subject flag, consent string
  - COPPA: subject flag
  - TCFv2: purpose consents (`getPurposeConsent(index)` for one purpose), device access consent
  - CCPA / US Privacy: `setUSPrivacyString()`, `getUSPrivacyString()`
  - GPP: auto-read from SharedPreferences/UserDefaults (CMP integration)
  - App First-Party Data: keywords, ext data (`app.ext.data`)
  - User First-Party Data: keywords, ext data (`user.ext.data`)
  - Access control list for bidder data access
  - Global OpenRTB configuration
  - App info: content URL, publisher name, store URL, domain
  - OM SDK partner: `setOmidPartnerName()`, `setOmidPartnerVersion()`
  - SKAdNetwork (iOS): `setSourceApp()`, `setItunesId()`
  - Location: `setUserLatLng()`, `setLocationPrecision()`
- **Error Handling** — load, show and render failures arrive through the listeners' `onAdFailed`; host calls return `Future`s that complete once the native side has applied the call
- **Fullscreen lifecycle** — reloading an interstitial / rewarded replaces the previous ad; `show()` presents from the top-most view controller and reports `onAdFailed` when the ad isn't loaded or can't be presented; native-side errors reach the caller's `Future`
- **Requests before initialization** — Prebid Android drops a request made before `initializeSdk` completes without calling back; the plugin reports it instead (`onAdFailed`, or the `prebidSdkNotInitialized` result code for `fetchDemand`)
- **Widget updates** — a banner rebuilt with a different configuration gets a new native view, and a swapped `PrebidBannerAdController` is re-attached; `PrebidNativeAdView` follows a different `ad`, and a reloaded `PrebidNativeAd` re-renders in the view already on screen
- **Native defaults** — `PrebidNativeAd` requests title, main image, icon, sponsored, description and call to action when `assets` is null (`PrebidNativeAd.defaultAssets`)
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
