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
  theme/app_theme.dart       docs-website palette (DemoColors), fonts, themes
  data/demo_item.dart        DemoItem model: integration, category, ScreenType,
                             config id (or random list), ad unit, size, flags…
  data/demo_items.dart       the 187 items, in the original order
  demo/demo_screen.dart      DemoScreen / DemoScreenState (the original
                             AdFragment), DemoScaffold, AdUnitIdLabel, buttons
  demo/event_counter.dart    EventCounters + EventCounterList (event rows)
  demo/configure_ad_dialog.dart  "Configure the Ad" (banner / interstitial)
  demo/demo_router.dart      DemoItem -> screen (unmatched -> placeholder)
  demo/screens/              screen families (A1 In-App banner, placeholder…)
  pages/                     Examples, Utilities, IAB consent, App settings,
                             Versions, developer_tools/
  platform/sdk_initializer.dart  start-up (Prebid, AppLovin MAX)
  platform/iab_consent_store.dart  raw IAB keys (example method channel)
  platform/pending_api.dart  every call to a plugin API that does not exist
                             yet (TODO(pending-api) stubs)
```

### Adding a screen

1. Create `lib/demo/screens/<name>_screen.dart`: a `DemoScreen` with a
   `DemoScreenState`. Implement `startAd()`, `destroyAd()` and `buildDemo()`,
   and use `config` (the effective config id and size), `EventCounters` with
   the exact row labels, `AdUnitIdLabel` and `DemoButton`.
2. Route it in `lib/demo/demo_router.dart`.

The base state already does the shared work:

- clears the stored auction response;
- applies the item's account, server and app-name overrides, and the random
  bid drop and custom renderer flags;
- shows the configurator;
- shows the progress overlay;
- restores the overrides on exit.

## Status

- Done: the shell, Examples, Utilities and the framework. Of the screens,
  **A1 for In-App banners** is done (25 cases).
- Placeholder: every other screen type opens a page with the case's registry
  data and "Screen type X — coming next".
- Waiting for plugin APIs: runtime account / server switch, Enable Caching,
  creative-factory getters, OMSDK version, app name, AdMob / MAX refresh,
  adaptive banners, multiformat mediation interstitials, MAX extra callbacks
  and the debug bid-drop hook. These calls go through stubs in
  `platform/pending_api.dart`.
- Custom renderer: these cases will be built in the example's native code.

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
