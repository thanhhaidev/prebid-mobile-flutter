---
status: accepted
date: 2026-10-10
---

# Android single-format Original API units use Prebid's legacy AdUnit classes

All Original API units currently go through `PrebidMultiformatAd`, which on Android builds Prebid's `PrebidAdUnit` + `PrebidRequest`. Those have no setters for `pbAdSlot`, `impOrtbConfig` or a per-unit `globalOrtbConfig` (only `PrebidRequest.setGpid`), so the plugin ignores them on Android and documents it as a platform difference.

Prebid Android 3.4's legacy `org.prebid.mobile.AdUnit` has all four (`setPbAdSlot`, `setGpid`, `setImpOrtbConfig`, `setGlobalOrtbConfig`), and its subclasses cover each single format: `BannerAdUnit`, `InterstitialAdUnit`, `RewardedVideoAdUnit` and `NativeAdUnit`. So on Android `PrebidBannerAdUnit`, `PrebidInterstitialAdUnit` and `PrebidNativeAdUnit` (and other single-format requests) are built on those classes, and only a true multiformat request, more than one format in one auction, keeps `PrebidAdUnit`.

## Consequences

- `pbAdSlot` and the ORTB configs work on both platforms for single-format units; on Android they stay iOS-only for multiformat requests. `platform-differences.mdx` and the dartdoc need updating when this lands.
- Android has two native request paths for the Original API; result codes, targeting keywords and `PrebidBidResponse` fields must stay the same across them.
- The legacy units have their own auto-refresh, which may replace the plugin timer of ADR-0004 for them.
