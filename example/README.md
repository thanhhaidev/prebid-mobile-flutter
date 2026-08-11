# Prebid Mobile Flutter Example App

This is a comprehensive showcase of the `prebid_mobile_flutter` plugin, structured to mirror the official [Prebid Android `PrebidInternalTestApp`](https://github.com/prebid/prebid-mobile-android/tree/master/Example/PrebidInternalTestApp).

## Overview

The demo app focuses exclusively on the **In-App (Prebid Rendered)** integration, where the Prebid SDK directly handles both the bidding auction and the ad rendering.

The UI mirrors the reference test app:

- **Bottom navigation** — an **Examples** tab and a **Utilities** tab (each keeps its own navigation stack, so the bottom bar stays visible on detail pages).
- **Examples** — a search bar, a single row of ad-type filter chips (All · Banner · Interstitial · Rewarded · MRAID · Video · Native), GDPR / PBS-Debug toggles, and a settings gear.
- **Detail pages** — a clean layout with the ad view, the config id, action buttons (Load / Show / Stop refresh / Fetch Demand), and a live callback counter for every listener event (`onAdX called - N ( +1 )`). The app-bar gear opens a **Configure the Ad** dialog to override the config id, size, and refresh delay.
- **Utilities** — IAB Consent Settings (GDPR / CCPA), App Settings (server / account / debug), Targeting Data, and Versions.

## Ad Formats Showcased

**50 test cases** mirroring the in-app (Prebid Rendering) section of the Prebid
Android [`PrebidInternalTestApp`](https://github.com/prebid/prebid-mobile-android/tree/master/Example/PrebidInternalTestApp).
Mediation/ad-server integrations (GAM, AdMob, AppLovin MAX), custom renderers,
and Android-only view patterns are out of scope — this plugin wraps the
rendering API only.

1. **Display Banner** — `320x50`, `300x250`, `728x90`, Multisize, Deeplink, plus
   No-Bids and Incorrect-VAST error cases.
2. **MRAID** — Expand (1/2 part), Resize (+ errors / expandable), Fullscreen,
   Viewability Compliance, Resize Negative, Load & Events, Test Properties/Methods.
3. **Video Banner (Outstream)** — Outstream, With End Card, No-Bids.
4. **Display Interstitial** — `320x480`, No-Bids, MRAID Fullscreen.
5. **Video Interstitial** — `320x480`, With/MRAID End Card, SkipOffset, Deeplink,
   Vertical, With Ad Configuration, No-Bids.
6. **Display Rewarded** — Default, Time+autoclose, Event+close.
7. **Video Rewarded** — Default/Time/Event, With/Without End Card, End Card
   variants, With Ad Configuration, No-Bids (with `onUserEarnedReward`).
8. **Native** — Native Styles and Native Links, rendered with custom Flutter UI
   from raw assets (Image, Title, CTA, Sponsored, Body).
9. **In-Stream Video** — `fetchDemand`-only, surfacing the returned targeting keywords.
10. **Multiformat** — Banner + Video + Native demand on a single ad unit.

Every detail page wires **all** listener callbacks for that ad unit and shows a
live per-callback counter, so each case can be verified end to end.

## Key Features

- **Test Case Registry:** Built-in list of Prebid-provided test configuration IDs and Stored Response IDs that guarantee fill, ensuring rapid QA and development.
- **Live Event Logger:** An expandable bottom sheet on every detail page that intercepts all SDK callbacks (e.g. `onAdLoaded`, `onAdFailed`, `onAdClicked`) with timestamps.
- **Stored Response Management:** Automatically handles setting and clearing `storedAuctionResponse` IDs behind the scenes so test cases don't cross-contaminate.
- **Settings Page:** Toggle GDPR, COPPA, Geo location sharing, and PBS debug logging. Configurations are persisted locally.
- **Targeting Data Page:** A comprehensive interface to define First-Party Data:
  - User and App Keywords
  - ExtData (key-value pairs)
  - Global ORTB configuration JSON
  - Publisher App Info (Content URL, Store URL, Domain)

## Running the App

```bash
cd example
flutter clean
flutter pub get

# To run on iOS device or simulator
flutter run -d ios

# To run on Android device or emulator
flutter run -d android
```

### Notes on Dependencies
- **iOS:** Ensure CocoaPods is updated, and you run `pod install` in the `example/ios` directory before building.
- **Android:** Requires API Level 24+ and compiles with Kotlin `1.9.0` minimum.
