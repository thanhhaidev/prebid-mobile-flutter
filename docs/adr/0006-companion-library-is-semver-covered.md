---
status: accepted
date: 2026-10-10
---

# The companion library is part of the core package's semver contract

`package:prebid_mobile_sdk/companion.dart` exports what the companion packages build on: `AdViewChannel`, `CompanionAdChannel` and `CompanionFullscreenAd` with its event dispatch helpers. Apps don't use it, but it is a public library of the core package, so it follows the core's semantic versioning: a breaking change to it ships only in a major release of `prebid_mobile_sdk`.

That lets each companion depend on `prebid_mobile_sdk: ^1.0.0` and be released on its own (RELEASING.md), instead of pinning the exact core release it was built with. The alternative, treating it as internal and free to change in any release, would force every companion to pin the core exactly and be re-released with each core release, and would let a core patch break an app's companion.

## Consequences

- The library's dartdoc, which still says it "may change in any release", has to say this instead.
- New companion needs are added to the library in a minor release; a companion that needs them raises its lower bound (`^1.x.0`).
- The docs' statement that every companion requires the core "at the same release" should become "a compatible release".
