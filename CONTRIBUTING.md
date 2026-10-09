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

## Making a change

1. Create a branch from `main`.
2. Make the change on **both platforms**. When the native SDKs can't behave
   the same, document the difference in
   `website/docs/platform-differences.mdx`.
3. Add or update unit tests (`packages/*/test`). The core package mocks the
   Pigeon host APIs with Mockito: after adding a host API, add it to
   `test/mock_host_api.dart` and run
   `dart run build_runner build --delete-conflicting-outputs` in
   `packages/prebid_mobile_sdk`. Companion tests use the channel harness in
   `test/channel_harness.dart`.
4. Try it in the example app on an Android device or emulator and an iOS
   simulator: `cd example && flutter run`.
5. For user-facing changes, add an entry under `## [Unreleased]` in the
   package's `CHANGELOG.md` ([Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
   format, describing the behavior rather than the code) and update the pages
   in `website/docs/`.

### Checks

CI runs these on every pull request; run them locally first:

```bash
dart run melos run format          # dart format
dart run melos run analyze         # flutter analyze, every package
dart run melos run test            # unit tests, every package
dart run melos run generate:check  # Pigeon output is up to date
dart run melos run compatibility:check
```

- Changed `pigeons/prebid_api.dart`? Run `dart run melos run generate` and
  commit the generated Dart, Kotlin and Swift files.
- Changed a native Prebid version? Update `website/src/data/compatibility.json`
  and run `dart run melos run compatibility` to refresh the README tables.

CI also builds the example for Android and iOS and runs
`pub publish --dry-run` for every package. Documentation changes are built by
the docs workflow (`cd website && npm ci && npm run build` locally).

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
