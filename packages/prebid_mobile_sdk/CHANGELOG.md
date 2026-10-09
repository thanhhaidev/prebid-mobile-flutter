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
- Identity: external user IDs (OpenRTB 2.6 EIDs) and Prebid SharedID.
- SDK configuration: timeouts, custom headers, Prebid Server targeting flags,
  stored responses, status check, log level, and a bid request and response
  listener for debugging.
- iOS privacy and attribution: a separate Prebid Server URL for users who
  haven't allowed tracking (App Tracking Transparency), and SKAdNetwork
  source app and iTunes ID.
- The same events and result codes on Android and iOS.
