---
status: accepted
date: 2026-10-11
---

# A preloaded banner's native view outlives the platform views that show it

`PrebidBannerAd` creates its Prebid `BannerView` with its platform view and destroys it with the view. In a scrolling list the view is disposed whenever its row scrolls away, so a row scrolled back runs a new auction. Prebid's own test apps move one `BannerView` between containers instead.

`PrebidPreloadedBannerAd` does the same. `BannerAdHostApi.create` builds the banner from the same creation params as a banner view, inside a `BannerAdSession` that both kinds of banner use, and keeps it by its channel ID (ADR-0005) until `destroy`. A platform view created with `preloaded: true` looks the session up and moves its `BannerView` into its own container; disposing that view takes the banner out only if it is still in its container. So the newest view showing a banner takes it over, and an older view that is disposed later leaves it alone. The Dart view waits for `create` to complete before building the platform view, since the lookup needs the session.

## Consequences

- A banner shows in one view at a time; there is no error when a second view shows it, because Flutter builds a moved widget's new element before disposing the old one.
- Prebid counts the impression and refreshes only while the creative is visible, on both platforms, so loading off screen counts nothing.
- The app owns the lifetime: a banner not destroyed lives until the engine detaches (`releaseAds`).
- `PrebidBannerAd` and the companion banners are unchanged.
