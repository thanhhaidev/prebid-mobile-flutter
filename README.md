# Prebid Mobile Flutter

A [Melos](https://melos.invertase.dev)-managed monorepo (Dart pub workspace) of
Flutter plugins that wrap the Prebid Mobile SDK for header bidding on Android
and iOS.

## Packages

| Package | Description |
|---|---|
| [`packages/prebid_mobile_sdk`](packages/prebid_mobile_sdk) | **Core plugin.** Prebid In-App (rendered) banner, interstitial, rewarded, native, multiformat, in-stream video, plus the Original API keyword handoff (`PrebidBannerAdUnit` / `PrebidInterstitialAdUnit`). Depends only on the Prebid SDK. |
| [`packages/prebid_mobile_sdk_gam`](packages/prebid_mobile_sdk_gam) | **Optional companion.** Google Ad Manager *rendering* via Prebid's GAM (next-gen) event handlers (banner, interstitial, rewarded, GAM native). Bundles the Google Mobile Ads SDK — kept separate so core stays lean. |
| [`packages/prebid_mobile_sdk_admob`](packages/prebid_mobile_sdk_admob) | **Optional companion.** Google AdMob *mediation* via Prebid's AdMob adapters (banner, interstitial, rewarded, native). Bundles the Google Mobile Ads SDK. |
| [`packages/prebid_mobile_sdk_max`](packages/prebid_mobile_sdk_max) | **Optional companion.** AppLovin MAX *mediation* via Prebid's MAX adapters (banner, interstitial, rewarded, native). Bundles the AppLovin MAX SDK. |
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

Requires the Flutter version pinned in `.fvmrc` (use [FVM](https://fvm.app) or
install it directly; CI reads the same file). A single resolve at the repo root
bootstraps every package via the pub workspace:

```bash
flutter pub get
```

### Melos scripts

```bash
dart run melos list                # list packages
dart run melos run analyze         # flutter analyze across all packages
dart run melos run test            # flutter test where a test/ dir exists
dart run melos run format          # dart format
dart run melos run format:check    # fail on unformatted files
dart run melos run generate        # regenerate (and format) the Pigeon API
dart run melos run generate:check  # fail if the Pigeon output is stale
dart run melos run publish:check   # pub publish --dry-run for every package
```

## CI / CD

- **CI** ([`flutter_ci.yml`](.github/workflows/flutter_ci.yml)), on every push
  to `main` and every pull request:
  - format, Pigeon codegen, analyze and test on Linux;
  - `pub publish --dry-run` for every package;
  - example builds: Android (Linux) and iOS (macOS), run after the checks pass.
- **Release** ([`release.yml`](.github/workflows/release.yml)), on a
  `<package>-v<version>` tag: publishes that package to pub.dev with GitHub
  OIDC (no stored token) and creates a GitHub release from its CHANGELOG. See
  [RELEASING.md](RELEASING.md).

## Run the example

```bash
cd example
flutter run
```

## License

[Apache License 2.0](LICENSE)
