# Releasing

Each package is versioned and published on its own. Publishing runs in
GitHub Actions ([`release.yml`](.github/workflows/release.yml)) through
[pub.dev automated publishing](https://dart.dev/tools/pub/automated-publishing),
so nobody needs a pub.dev token on their machine.

| Package | Tag |
|---|---|
| `prebid_mobile_sdk` | `prebid_mobile_sdk-v<version>` |
| `prebid_mobile_sdk_gam` | `prebid_mobile_sdk_gam-v<version>` |
| `prebid_mobile_sdk_admob` | `prebid_mobile_sdk_admob-v<version>` |
| `prebid_mobile_sdk_max` | `prebid_mobile_sdk_max-v<version>` |

## One-time setup

pub.dev can only enable automated publishing for a package that already
exists, so the **first version of each package is published by hand**:

```bash
cd packages/prebid_mobile_sdk && flutter pub publish        # core first
cd ../prebid_mobile_sdk_gam && flutter pub publish
cd ../prebid_mobile_sdk_admob && flutter pub publish
cd ../prebid_mobile_sdk_max && flutter pub publish
```

Then, for each package on pub.dev, open **Admin → Automated publishing**:

1. Enable **Publishing from GitHub Actions**.
2. Repository: `thanhhaidev/prebid-mobile-flutter`.
3. Tag pattern: `<package>-v{{version}}` (e.g. `prebid_mobile_sdk-v{{version}}`).
4. Optional but recommended: require the GitHub environment `pub.dev`, and in
   the GitHub repo settings add protection rules to that environment
   (required reviewers, tags only).

## Releasing a version

1. Bump `version:` in the package's `pubspec.yaml` and rename the
   `## [Unreleased]` section of its `CHANGELOG.md` to `## [<version>] - <date>`
   (contributors add their entries under `[Unreleased]`). If a companion needs a new core API, bump
   its `prebid_mobile_sdk: ^x.y.z` constraint too.
2. Add an entry for the new version at the top of the package's `releases`
   in [`website/src/data/compatibility.json`](website/src/data/compatibility.json)
   (native Prebid and ad SDK versions, minimum OS versions), then run
   `dart run melos run compatibility` to regenerate the README tables. CI
   fails while the newest entry disagrees with the package's
   `pubspec.yaml`, `build.gradle.kts`, podspec or `Package.swift`.
3. Open a PR; CI runs `pub publish --dry-run` for every package.
4. After merging, tag the commit on `main` and push the tag:

   ```bash
   git tag prebid_mobile_sdk-v1.0.1
   git push origin prebid_mobile_sdk-v1.0.1
   ```

5. The Release workflow checks that the tag matches `pubspec.yaml` and the
   CHANGELOG, analyzes and tests the package, publishes it, and creates a
   GitHub release from the CHANGELOG section.

**Order:** release `prebid_mobile_sdk` before any companion that depends on
its new version. The workflow refuses to publish a companion while the core
version in the repo is not on pub.dev yet.

To check a package without publishing, run the Release workflow manually
(**Actions → Release → Run workflow**) and pick the package. That run only
does the dry run.

## Native SDK updates

- **Dependabot** opens one PR for the `org.prebid:*` Android artifacts of all
  packages, and one for a new major of the Swift packages.
- **[Native SDK check](.github/workflows/native-sdk-check.yml)** runs every
  Monday: it compares the newest Prebid releases (Maven Central, CocoaPods
  trunk) with `website/src/data/compatibility.json` and opens or updates an
  issue labeled `native-sdk-update` with a checklist. It covers what
  Dependabot can't: CocoaPods and minor iOS releases. Run it locally with
  `.github/scripts/native-sdk-check.sh --dry-run`.

A Prebid update touches Android and iOS together: bump the Gradle artifacts,
the podspec and `Package.swift` minimums, and `compatibility.json` in one PR,
then release as above. CI's compatibility check fails until they agree.

## Documentation

The site in [`website/`](website) deploys to GitHub Pages on every push to
`main` that touches it, a CHANGELOG or a native dependency, and after each
Release run (the changelog page shows tag dates). The site has one docs
version, so update the pages in `website/docs/` in the same PR as the
release.

One-time setup: in the repo settings, **Pages → Source: GitHub Actions**.
