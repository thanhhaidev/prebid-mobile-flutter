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

1. Bump `version:` in the package's `pubspec.yaml` and add a `## <version>`
   section to its `CHANGELOG.md`. If a companion needs a new core API, bump
   its `prebid_mobile_sdk: ^x.y.z` constraint too.
2. Open a PR; CI runs `pub publish --dry-run` for every package.
3. After merging, tag the commit on `main` and push the tag:

   ```bash
   git tag prebid_mobile_sdk-v0.0.2
   git push origin prebid_mobile_sdk-v0.0.2
   ```

4. The Release workflow checks that the tag matches `pubspec.yaml` and the
   CHANGELOG, analyzes and tests the package, publishes it, and creates a
   GitHub release from the CHANGELOG section.

**Order:** release `prebid_mobile_sdk` before any companion that depends on
its new version. The workflow refuses to publish a companion while the core
version in the repo is not on pub.dev yet.

To check a package without publishing, run the Release workflow manually
(**Actions → Release → Run workflow**) and pick the package. That run only
does the dry run.
