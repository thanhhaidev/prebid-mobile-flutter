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

## The wire protocol is part of the contract

The library's classes speak to each companion's native code, which ships in the companion package, not in the core. So the messages they exchange are part of the same contract: a core minor release may add messages but not rename, remove or reshape these, or a companion released against an older core breaks.

**Ad views** (`AdViewState`, `PreloadedBanner`):

- The platform view gets a `channelId` creation param and names its channel `<viewType>_<channelId>` (ADR-0005). A preloaded banner's view also gets `preloaded: true` (ADR-0008).
- Native → Dart: `onAdSize` `{width?, height}` (logical pixels; a report without a positive height is dropped), then the banner events `onAdLoaded`, `onAdDisplayed`, `onAdFailed` (`error` string, or the payload itself), `onAdClicked`, `onAdImpression`, `onAdClosed`, `onAdExpired` and the `onVideo…` events.
- Dart → native: `loadAd` and `stopRefresh` (`PrebidBannerAdController`), and `setVisibleFraction` (a double, 0–1, two decimals) when `reportsVisibleFraction` is on. A view that doesn't handle a call answers "not implemented", which the library ignores.

**Preloaded banners** (`PreloadedBanner.companion`), on the package's `<package>/preloaded_banner` channel: `create` `{channelId, config}` (the banner widget's creation params, `channelId` included) and `destroy` `{channelId}`.

**Fullscreen ads** (`CompanionAdChannel`, `CompanionFullscreenAd`), one channel per ad kind:

- Dart → native: `releaseAll` once, before the first other call (hot restart); `load` `{adId, …}`, `show` `{adId}`, `destroy` `{adId}`.
- Native → Dart: events named as the listener callbacks (`onAdLoaded`, `onAdFailed`, `onAdDisplayed`, `onAdClosed`, `onAdClicked`, `onAdImpression`, `onAdExpired`, `onUserEarnedReward`), each with `adId`; `onAdFailed` carries `error`, `onUserEarnedReward` `rewardType`, `rewardCount` and an optional `rewardExt`.
