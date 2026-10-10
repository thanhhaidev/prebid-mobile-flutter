---
status: accepted
date: 2026-10-10
---

# In-App native impressions are measured by the plugin, not taken from Prebid

Prebid fires a native impression when a tracker request succeeds, not when the ad is seen. Prebid iOS calls `adDidLogImpression` only after an `eventtrackers` URL request succeeds: never when the response has no event trackers, and only after a 300 s retry when the request fails. Prebid Android calls `onAdImpression` once per impression tracker request, from a background thread, and also not at all without trackers. On a slow server iOS impressions never reached Dart.

So `PrebidNativeAdView` reports `onAdImpression` itself, using the IAB rule Prebid applies before firing its trackers: at least half the view on screen for one second, polled every 0.25 s (five consecutive viewable checks), once per ad (`NativeAdEvents.kt`, `NativeAdEventForwarder.swift`). Native code can't see Flutter's clips (a list scrolled under an app bar is masked, not moved), so the widget also sends the fraction Flutter actually paints (`lib/src/internal/visibility.dart`) and the view must pass both checks. Prebid's own callback stays as a fallback and Prebid still fires its trackers.

## Consequences

- The core's impression is viewability-based; the GAM companion's Prebid native creative keeps Prebid's tracker callback, and AdMob / MAX report their SDK's impression. The docs call this out (events, gam, platform-differences).
