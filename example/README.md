# Prebid Mobile Flutter Example App

> **Unofficial project.** This is an independent, community-maintained
> Flutter wrapper around the official
> [Prebid Mobile SDKs](https://docs.prebid.org/prebid-mobile/prebid-mobile-getting-started.html).
> It is not affiliated with, endorsed by, or maintained by Prebid.org. Report
> issues with this plugin in [its repository](https://github.com/thanhhaidev/prebid-mobile-flutter/issues),
> not to Prebid.

A test app for the `prebid_mobile_sdk` plugin and its GAM / AdMob / MAX
companion packages. It mirrors Prebid's Android
[`PrebidInternalTestApp`](https://github.com/prebid/prebid-mobile-android/tree/master/Example/PrebidInternalTestApp):
the same screens, the same 187 test cases in the same order, with the same
labels, config ids, ad unit ids, sizes and behaviour. The visual style follows
this project's docs website (navy bars, Prebid orange, Rethink Sans and
JetBrains Mono, light and dark).

Every case runs a live auction against Prebid's public test server
(`prebid-server-test-j.prebid.org`, account
`0689a263-318d-448b-a3d4-b02e8a709d9d`).

## Screens

- **Bottom navigation**: **Examples** and **Utilities**. The bar is always
  visible. Switching tabs returns to the tab's root, as in the original.
- **Examples** ("Prebid Rendering Flutter Demo"):
  - a search box (matches labels);
  - integration filter: In-App · GAM · Original · AdMob · Max · All;
  - category filter: Banner · Interstitial · MRAID · Video · Native · All;
  - **Enable GDPR**: writes the raw IAB keys `IABTCF_gdprApplies` and
    `IABTCF_CmpSdkID`. It is on for a fresh install;
  - **Enable Caching**;
  - the configuration toggle: when it is on, a demo shows **Configure the Ad**
    (config id, size, refresh, or min-size percentages) before it loads;
  - the list of cases.
- **Demo screens**: the title is the case label. The ad loads as soon as the
  screen opens. Below it are the `AdUnitId: <configId>` label, the original
  buttons (Load, Stop refresh, ...) and the original event rows
  (`onAdLoaded called  -  2 ( +1 )`). Tap a lit row to acknowledge it.
- **Utilities**:
  - **IAB Consent Settings**: TCF v1 / v2, CCPA and KeepSettings, written as
    raw IAB keys to Android's default SharedPreferences or iOS's
    `NSUserDefaults.standard`;
  - **App settings**: "Show Progress Dialog";
  - **Versions**: Prebid, GAM and OMSDK versions;
  - **Developer tools** (extras that are not in the original):
    - SDK settings overrides (server, account, timeouts, PBS debug, privacy,
      theme);
    - Bid Inspector and the last bid response;
    - targeting data;
    - the event log;
    - about.

    SDK overrides only apply when you change them, so by default the app
    starts exactly like the original.

## Code layout

```
lib/
  main.dart, app.dart        entry point, MaterialApp, bottom-tab shell
  data/
    demo_item.dart           DemoItem model: integration, category, ScreenType,
                             config id (or random list), ad unit, size, flags…
    demo_items.dart          the 187 items, in the original order
  demo/
    demo_screen.dart         DemoScreen / DemoScreenState (the original
                             AdFragment), DemoScaffold, AdUnitIdLabel, buttons
    event_counter.dart       EventCounters + EventCounterList (event rows)
    configure_ad_dialog.dart "Configure the Ad" (banner / interstitial)
    demo_router.dart         DemoItem -> screen, through the families
    families/                one router per screen family
    screens/                 banner/, fullscreen/, native/, mediation/,
                             special/ (in-stream, multiformat, PUC), shared/
  pages/                     Examples, Utilities, IAB consent, App settings,
                             Versions, developer_tools/
  services/                  app settings, SDK start-up, IAB consent store,
                             custom renderer channel, bid inspector, logger
  theme/app_theme.dart       docs-website palette (DemoColors), fonts, themes
  widgets/                   shared widgets (segmented row, list row, header)
```

### Adding a screen

1. Create the screen under `lib/demo/screens/<family>/`: a `DemoScreen` with
   a `DemoScreenState`. Implement `startAd()`, `destroyAd()` and
   `buildDemo()`, and use `config` (the effective config id and size),
   `EventCounters` with the exact row labels, `AdUnitIdLabel` and
   `DemoButton`.
2. Route it in the family's `lib/demo/families/<family>_family.dart`.
   `test/demo_router_test.dart` fails while any item has no screen.

The base state already does the shared work:

- clears the stored auction response;
- applies the item's account, server and app-name overrides, and the random
  bid drop and custom renderer flags;
- shows the configurator;
- shows the progress overlay;
- restores the overrides on exit.

## Differences from the original

Where Flutter or `google_mobile_ads` can't match the native app, the screen
says so in its doc comment:

- **Reusable banner, RecyclerView and feeds:** one ad per slot. A platform
  view can't be moved between parents.
- **GAM Original custom native formats and the multiformat screen:**
  `google_mobile_ads` has no custom native formats, so they use a GAM banner
  request or `PrebidGamNativeAd`.
- **PluginEventListener variants:** the plugin owns the ad view, so they run
  the custom renderer alone.
- **Native links (C3):** the four link buttons are listed under the ad.

## Running the app

```bash
cd example
flutter pub get
flutter run
```

- **iOS**: iOS 15+. Run `pod install` in `example/ios` after adding native
  files to a plugin. The Xcode project is signed with the maintainer's team
  (`DEVELOPMENT_TEAM`); to run on a device, pick your own team under
  **Runner → Signing & Capabilities**. Simulators need no signing.
- **Android**: minSdk 24. The GMA app id is the original's
  (`ca-app-pub-1875909575462531~6255590079`, `AD_MANAGER_APP=true`).
- **AppLovin MAX**: initialized at start-up with the original's SDK key
  (`applovin_max`; mediation provider "max"). The key is also declared in
  the Android manifest and the iOS `Info.plist`.
- **Fonts**: Rethink Sans and JetBrains Mono, bundled in `assets/fonts/`
  (SIL OFL 1.1).
