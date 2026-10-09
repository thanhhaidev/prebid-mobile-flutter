# Prebid Mobile Flutter Example App

A test app for the `prebid_mobile_sdk` plugin and its GAM / AdMob / MAX
companion packages, structured like Prebid's
[`PrebidInternalTestApp`](https://github.com/prebid/prebid-mobile-android/tree/master/Example/PrebidInternalTestApp).
Every case runs a live auction against Prebid's public test server
(`prebid-server-test-j.prebid.org`).

## Layout

- **Bottom navigation**: an **Examples** tab and a **Utilities** tab. Each tab
  keeps its own navigation stack, so the bottom bar stays visible.
- **Examples**: search, integration filter (In-App · GAM · Original · AdMob ·
  Max), format filter (Banner · Interstitial · MRAID · Video · Native), GDPR /
  PBS-debug toggles.
- **Utilities**: IAB consent (GDPR / CCPA), Settings, Bid Inspector, Targeting
  Data, Logs, Versions.

## Test cases

90+ cases with the reference app's config ids and ad-unit ids:

| Integration | Formats |
|---|---|
| **In-App** (Prebid renders) | Banner (sizes, multisize, deeplink, no-bids), MRAID 2.0 / 3.0, video outstream, display / video interstitial, display / video rewarded, native (styles, links), in-stream, multiformat |
| **GAM** (Prebid GAM event handlers) | Banner, MRAID, video outstream, display / video interstitial, rewarded, native custom template + unified |
| **GAM Original API** (keywords to `google_mobile_ads`) | Banner sizes, video banner, filter-uncached-bids banner, display / video / multiformat interstitial, video rewarded |
| **AdMob** / **MAX** (Prebid mediation adapters) | Banner, display / video interstitial, video rewarded, native |

## Test case screen

Each case uses the same layout:

1. **Ad stage**: the inline ad (banner / native).
2. **Ad unit header**: config id and ad-server ad unit, tap to copy.
3. **Actions**: Load / Show / Stop refresh / Fetch Demand.
4. **Callback rows**: one per listener callback for that integration, lit up
   with its count once it fires. Examples:
   - In-App / GAM banners: `onAdExpired` and outstream video events
     (`onVideoCompleted`, paused, resumed, muted, unmuted).
   - AdMob / MAX: `onAdImpression`.
   - Rewarded: `onUserEarnedReward` with the reward.
   - GAM native: the full `fetchDemand` → custom / unified → `onNativeAdLoaded`
     / `onPrimaryAdWin` flow.
5. **Last bid response**: bidders and prices from the latest auction. Tap it for
   the JSON.
6. **Event log**: every callback with a timestamp and its details (errors,
   rewards, winning bid, `exp`, `topBidFiltered`).

The gear icon opens **Configure the Ad**:

- **Banners**: config id, size, auto-refresh.
- **Interstitial / rewarded**: config id plus `PrebidFullscreenControls`
  (close / skip button position and area, skip delay, mute, sound button,
  auto-close, minimum size).

## Utilities

- **Settings**: server URL and account, bid timeout, auction settings id, PBS
  debug, geo, log level, creative factory timeouts, filter uncached bids, EIDs
  placement, include winners / bidder keys, SharedID (send, view, reset),
  COPPA / GDPR. Settings are persisted and applied at startup.
- **Bid Inspector**: every Prebid Server request / response pair captured with
  `PrebidMobile.setEventListener`, as pretty JSON with copy.
- **Targeting Data**: user / app keywords, ext data, global ORTB config, app
  info, OMID partner, user location and location precision.
- **Logs**: SDK setup and every ad callback across all screens.

## Running the app

```bash
cd example
flutter pub get
flutter run
```

- **iOS**: iOS 15+. Run `pod install` in `example/ios` after adding native
  files to a plugin.
- **Android**: minSdk 24.
- **AppLovin MAX**: MAX only loads ads after the AppLovin SDK is initialized
  with an SDK key. This example does not initialize it, so MAX cases may not
  fill on iOS.
