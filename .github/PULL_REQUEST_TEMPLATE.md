## Summary

<!-- What does this change, and why? Link the issue: "Closes #123". -->

## Type

<!-- The PR title must follow Conventional Commits, e.g. "fix(native): report onAdExpired on iOS"; it becomes the commit message. -->

- [ ] Bug fix
- [ ] New feature or API
- [ ] Breaking change
- [ ] Documentation, example app or CI only

## Packages

- [ ] `prebid_mobile_sdk`
- [ ] `prebid_mobile_sdk_gam`
- [ ] `prebid_mobile_sdk_admob`
- [ ] `prebid_mobile_sdk_max`

## Checklist

- [ ] Unit tests cover the change, and `dart run melos run test` passes
- [ ] `dart run melos run format:check` and `dart run melos run analyze` pass
- [ ] Pigeon API changed: regenerated with `dart run melos run generate`
- [ ] Native SDK version changed: `website/src/data/compatibility.json` updated and `dart run melos run compatibility` run
- [ ] Behaves the same on Android and iOS, or the difference is documented in `website/docs/platform-differences.mdx`
- [ ] User-facing change: entry under `## [Unreleased]` in the package's `CHANGELOG.md`, and docs in `website/docs/` updated

## Testing

<!-- How you verified it: devices / simulators, OS versions, example app test cases. Screenshots or logs for UI and ad behavior. -->

- [ ] Android:
- [ ] iOS:
