# Prebid Mobile Flutter Example App

This is a comprehensive showcase of the `prebid_mobile_flutter` plugin, meticulously structured to mirror the official [Prebid iOS Demo App](https://github.com/prebid/prebid-mobile-ios/tree/master/Example/PrebidDemo).

## Overview

The demo app focuses exclusively on the **In-App (Prebid Rendered)** integration, where the Prebid SDK directly handles both the bidding auction and the ad rendering. 

It provides 6 core ad detail pages, each tailored to specific formats, alongside a robust Settings and Targeting Data manager.

## Ad Formats Showcased

1. **Banner**
   - Display Banner (`320x50`, `300x250`)
   - Video Banner (Outstream `300x250`)
2. **Interstitial**
   - Display Interstitial (`320x480`)
   - Video Interstitial (`320x480` Vertical & Landscape)
3. **Rewarded**
   - Display Rewarded
   - Video Rewarded (`320x480`)
4. **Native**
   - Banner Native Styles
   - Custom Flutter UI rendering using native raw assets (Image, Title, CTA, Sponsored)
5. **Video**
   - Standalone In-App Video
6. **Multiformat**
   - Requesting multiple demand sources simultaneously on a single Ad Unit ID.

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
