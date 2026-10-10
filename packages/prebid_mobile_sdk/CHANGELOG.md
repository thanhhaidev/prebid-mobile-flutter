# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the package uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-10

First stable release, built on Prebid Mobile SDK 3.4 (Android 3.4.0, iOS 3.4.1
or later). Requires Android 7.0 (API 24) and iOS 15.

### Added

- Prebid-rendered ads: banner (display, multisize, outstream video,
  auto-refresh), interstitial, rewarded, and native with built-in rendering
  and impression and click tracking.
- Original API auctions for banner, interstitial, native, multiformat and
  in-stream video, returning targeting keywords for Google Ad Manager, with
  auto-refresh and Prebid impression tracking.
- OpenRTB 2.6 video signals: placement, start delay, linearity, skippability,
  blocked creative attributes, bitrates and durations.
- Fullscreen rendering controls: close and skip buttons, skip delay, sound,
  minimum size, and SKOverlay on iOS.
- Bid expiration events for every ad format.
- Privacy signals: GDPR (TCF v2), US Privacy (CCPA) and COPPA, plus GPP read
  from the consent management platform.
- First-party data: user and app keywords and data, bidder access control,
  global and per-impression OpenRTB configuration, app information and
  location.
- Identity: external user IDs (OpenRTB 2.6 EIDs, several IDs per source,
  with entry- and ID-level `ext`) and Prebid SharedID.
- SDK configuration: timeouts, custom headers, Prebid Server targeting flags,
  stored responses, status check, log level, and a bid request and response
  listener for debugging.
- Runtime switching of the Prebid Server account and auction endpoint without
  re-initializing, with getters.
- Creative factory timeout getters, caching of Rendering API bids for
  reporting, the bundled OM SDK version, and an `app.name` override.
- iOS privacy and attribution: a separate Prebid Server URL for users who
  haven't allowed tracking (App Tracking Transparency), and SKAdNetwork
  source app and iTunes ID.
- Native ads in your own Flutter layout (`PrebidNativeAdView.custom`) with
  impression and click tracking, and Original API native wins shown from
  their cache id (`PrebidNativeAd.loadFromCacheId`).
- `NativeParameters`, the native request every native ad takes (assets,
  event trackers, context, placement count, sequence, asset and DCO URL
  support, privacy, `ext`), with image MIME types and `ext` fields on assets
  and event trackers.
- Per-ad-unit global OpenRTB configuration for banner, interstitial,
  rewarded, native and in-stream video.
- Rewarded ad formats, video parameters and minimum size (iOS), and
  `isLoaded` on interstitial and rewarded ads.
- Video player size in video parameters (`video.w` / `video.h`).
- The winning bid of a Prebid-rendered banner
  (`PrebidBannerAdController.winningBid`).
- Original API: the Prebid creative size in a GAM banner
  (`findPrebidCreativeSize`), bid event URLs, banner API frameworks, the
  interstitial minimum size, GPID on every ad unit, and SKAdNetwork StoreKit
  flows and SKOverlay on iOS.
- Original API: `NativeParameters` on native and multiformat units, a
  display interstitial requested by minimum size alone, and `pbAdSlot` plus
  per-unit OpenRTB configuration (iOS).
- Prebid ad slot (`pbAdSlot`) on interstitial and rewarded ads.
- Prebid's log messages delivered to the app (`PrebidMobile.setLogListener`)
  and a `none` log level.
- The Google Ad Manager VAST tag URL for IMA players
  (`PrebidInstreamVideoAd.generateInstreamUriForGam`).
- Native response image sizes (iOS), the device-data consent check, an
  `app.bundle` override (Android), Prebid's own location updates switch
  (iOS), and clearing the user location.
- Getters for the SDK settings and targeting values.
- The same events and result codes on Android and iOS.
