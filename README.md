# Prebid Mobile Flutter

A [Melos](https://melos.invertase.dev)-managed monorepo (Dart pub workspace) of
Flutter plugins that wrap the Prebid Mobile SDK for header bidding on Android
and iOS.

## Packages

| Package | Description |
|---|---|
| [`packages/prebid_mobile_sdk`](packages/prebid_mobile_sdk) | **Core plugin.** Prebid In-App (rendered) banner, interstitial, rewarded, native, multiformat, in-stream video, plus the Original API keyword handoff (`PrebidBannerAdUnit` / `PrebidInterstitialAdUnit`). Depends only on the Prebid SDK. |
| [`packages/prebid_mobile_sdk_gam`](packages/prebid_mobile_sdk_gam) | **Optional companion.** Google Ad Manager *rendering* via Prebid's GAM (next-gen) event handlers (`PrebidGamBannerAd` / `PrebidGamInterstitialAd`). Bundles the Google Mobile Ads SDK — kept separate so core stays lean. |
| [`packages/prebid_mobile_sdk_admob`](packages/prebid_mobile_sdk_admob) | **Optional companion.** Google AdMob *mediation* via Prebid's AdMob adapters (`PrebidAdMobBannerAd` / `PrebidAdMobInterstitialAd`). Bundles the Google Mobile Ads SDK. |
| [`packages/prebid_mobile_sdk_max`](packages/prebid_mobile_sdk_max) | **Optional companion.** AppLovin MAX *mediation* via Prebid's MAX adapters (`PrebidMaxBannerAd` / `PrebidMaxInterstitialAd`). Bundles the AppLovin MAX SDK. |
| [`example`](example) | Demo app exercising the packages. |

See each package's README for its API. Start with
[`packages/prebid_mobile_sdk`](packages/prebid_mobile_sdk/README.md).

## Repository layout

```
.
├── melos.yaml                 # Melos task runner config
├── pubspec.yaml               # pub workspace root
├── packages/
│   ├── prebid_mobile_sdk/       # core plugin
│   ├── prebid_mobile_sdk_gam/   # GAM rendering companion
│   ├── prebid_mobile_sdk_admob/ # AdMob mediation companion
│   └── prebid_mobile_sdk_max/   # AppLovin MAX mediation companion
└── example/                     # demo app
```

## Getting started

Requires the Flutter SDK (Dart `^3.11.0`). A single resolve at the repo root
bootstraps every package via the pub workspace:

```bash
flutter pub get
```

### Melos scripts

```bash
dart run melos list          # list packages
dart run melos run analyze   # flutter analyze across all packages
dart run melos run test      # flutter test where a test/ dir exists
dart run melos run format    # dart format
```

## Run the example

```bash
cd example
flutter run
```

## License

[Apache License 2.0](LICENSE)
