# Contributing

Thanks for helping improve the Prebid Mobile Flutter plugins. This is an
unofficial, community-maintained project; questions about Prebid Server,
bidders or the native Prebid SDKs themselves belong to
[Prebid.org](https://docs.prebid.org).

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Before you start

- **Bugs:** open an issue with the bug report form, including a minimal
  reproduction. Security issues go through [SECURITY.md](SECURITY.md) instead.
- **Features:** open a feature request first for anything beyond a small fix,
  so the API can be agreed on before you write it. New APIs should map to
  something the Prebid Mobile SDK supports on both Android and iOS.

## Setup

The repo is a [Melos](https://melos.invertase.dev) monorepo on a Dart pub
workspace. Use the Flutter version pinned in `.fvmrc` (with
[FVM](https://fvm.app): `fvm install`), plus Xcode for iOS and JDK 17 for
Android.

```bash
git clone https://github.com/<you>/prebid-mobile-flutter.git
cd prebid-mobile-flutter
flutter pub get            # resolves every package in the workspace
```

| Path | Content |
| --- | --- |
| `packages/prebid_mobile_sdk` | Core plugin: Dart API, Pigeon definitions (`pigeons/`), Kotlin and Swift |
| `packages/prebid_mobile_sdk_{gam,admob,max}` | Companion packages (method channels) |
| `example/` | Test app with every integration |
| `website/` | Documentation site; `src/data/compatibility.json` holds the native SDK versions |
| `GLOSSARY.md`, `docs/adr/` | The domain terms, and the decisions behind the design (read them before reworking an area) |

## Making a change

1. Create a branch from `main`.
2. Make the change on **both platforms**. When the native SDKs can't behave
   the same, document the difference in
   `website/docs/platform-differences.mdx`.
3. Add or update tests, written test-first where you can:
   - **Dart** (`packages/*/test`), one file per public module
     (`interstitial_ad_test.dart`, `targeting_test.dart`…), never one per
     change. Test through the public API and mock only the platform: the
     core mocks the Pigeon host APIs with Mockito and sends native events
     over the Pigeon channels (`test/platform_events.dart`); the companions
     use `test/channel_harness.dart`. Expected values are literals (`7`, not
     `PrebidAdPosition.fullScreen.value`). After adding a host API, add it to
     `test/mock_host_api.dart` and run
     `dart run build_runner build --delete-conflicting-outputs` in
     `packages/prebid_mobile_sdk`.
   - **Kotlin** (`packages/*/android/src/test`) and **Swift**
     (`example/ios/RunnerTests`) for the native argument parsing and
     conversions.
4. Try it in the example app on an Android device or emulator and an iOS
   simulator: `cd example && flutter run`.
5. For user-facing changes, add an entry under `## [Unreleased]` in the
   package's `CHANGELOG.md` ([Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
   format, describing the behavior rather than the code) and update the pages
   in `website/docs/`.

### Checks

CI runs these on every pull request; run them locally first:

```bash
dart run melos run format:check    # dart format (`format` to fix)
dart run melos run analyze         # flutter analyze + tool/check_copies.sh
dart run melos run test            # Dart unit tests, every package
dart run melos run generate:check  # Pigeon output is up to date (stage first)
dart run melos run compatibility:check

# Native unit tests (build the example once so the Gradle and Xcode projects exist)
cd example/android && ./gradlew :prebid_mobile_sdk:testDebugUnitTest \
  :prebid_mobile_sdk_gam:testDebugUnitTest :prebid_mobile_sdk_admob:testDebugUnitTest \
  :prebid_mobile_sdk_max:testDebugUnitTest
cd example/ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=<an iPhone simulator>'
```

- Changed `pigeons/prebid_api.dart`? Run `dart run melos run generate` and
  commit the generated Dart, Kotlin and Swift files.
- Changed a native Prebid version? Update `website/src/data/compatibility.json`
  and run `dart run melos run compatibility` to refresh the README tables.

CI also builds the example for Android and iOS, runs the native unit tests,
the pub.dev score and `pub publish --dry-run` for every package. Documentation changes are built by
the docs workflow (`cd website && npm ci && npm run build` locally).

## Code style

### Layout

```
packages/prebid_mobile_sdk/
  lib/prebid_mobile_sdk.dart   the public API: exports only
  lib/src/                     one file per public feature (banner_ad.dart, targeting.dart…)
  lib/src/internal/            not exported: event routers, Pigeon conversions, ad ids, session
  lib/src/companion/           exported only by lib/companion.dart, for the companion packages
                               (AdViewState, CompanionFullscreenAd…); semver-covered like the rest
  lib/src/generated/           Pigeon output; never edit
  pigeons/prebid_api.dart      the Pigeon definitions
  android/…/io/github/thanhhaidev/prebid_mobile_sdk/  PrebidMobileSdkPlugin.kt, one <Name>HostApiImpl.kt
                               per host API, the platform-view factories, PigeonConversions and
                               PrebidCommon (shared with the GAM package)
  ios/…/Sources/prebid_mobile_sdk/  the same files in Swift
packages/prebid_mobile_sdk_<gam|admob|max>/
  lib/src/<prefix>_<format>_ad.dart; android/ and ios/ with one file per format,
  the files every companion shares (PrebidRequests, FullscreenAdManager,
  PrebidPlugin) and PrebidShared (each package's own helpers)
example/lib/
  data/ demo/ pages/ services/ theme/ widgets/   see example/README.md
```

### Naming

- **Packages and files:** `snake_case`. Android packages and the example's
  application ID live under `io.github.thanhhaidev` (the docs site's domain);
  never `com.prebid` or `org.prebid`, which belong to Prebid. Dart, Kotlin and Swift sources
  that implement the same thing share a name: `RewardedAdHostApiImpl.kt` and
  `RewardedAdHostApiImpl.swift`.
- **Public Dart types:** a `Prebid` prefix (`PrebidBannerAd`,
  `PrebidGamNativeAd`); a companion adds its ad server after the prefix
  (`PrebidAdMob…`, `PrebidMax…`). Enums and value types that mirror a native
  Prebid type keep its name (`VideoParameters`, `NativeAsset`), unless that
  name is also exported by `google_mobile_ads` or `applovin_max`, which apps
  import next to these packages: then it takes the prefix too
  (`PrebidAdFormat`, `PrebidInitializationStatus`).
- **Plugin classes:** what `flutter create` generates from the package name,
  on both platforms: `PrebidMobileSdkPlugin`, `PrebidMobileSdkGamPlugin`,
  `PrebidMobileSdkAdmobPlugin`, `PrebidMobileSdkMaxPlugin`.
- **Pigeon host APIs:** `<Name>HostApiImpl` on both platforms.
- **Channels and platform-view types:** prefixed with the package name:
  `prebid_mobile_sdk/banner_ad`, `prebid_mobile_sdk_gam/interstitial`.

### Style

- **Dart:** [Effective Dart](https://dart.dev/effective-dart) and
  `dart format`. Every package and the example use the same lint rules. A
  published package can't include a file outside itself, so each one keeps
  its own copy of `analysis_options.yaml`, and `tool/check_copies.sh` (part of
  `melos run analyze`) fails when a copy drifts. Change the rules in every
  copy at once. The same check keeps identical the companions'
  `test/channel_harness.dart`, their shared native files (`PrebidRequests`,
  `FullscreenAdManager`, `PrebidPlugin` and the `PrebidRequestsTest.kt` unit
  test; the Kotlin copies differ only in their package line) and the
  `PrebidCommon` files of the core and GAM packages: change those in every
  copy at once.
- **Kotlin:** [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html):
  imports instead of fully qualified names, KDoc (`/** */`) for declarations,
  `//` inside bodies.
- **Swift:** [API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/),
  `///` doc comments, `final` classes unless subclassed.
- **Comments:** say why, or what the native SDK does that the code works
  around; don't restate the code.

## Pull requests

- **Title:** [Conventional Commits](https://www.conventionalcommits.org/),
  e.g. `fix(native): report onAdExpired on iOS` or `feat(gam): add custom
  targeting to native`. Types: `feat`, `fix`, `docs`, `style`, `refactor`,
  `perf`, `test`, `build`, `ci`, `chore`, `revert`. Pull requests are
  squash-merged and the title becomes the commit message.
- Fill in the template: what changed, why, and how you tested it on each
  platform.
- Keep a pull request to one change; unrelated fixes go in separate ones.
- All checks must pass and the maintainer must approve before merging.

Releases are cut by the maintainer; see [RELEASING.md](RELEASING.md).

## License

Contributions are licensed under the [MIT License](LICENSE), the
license of this repository.
