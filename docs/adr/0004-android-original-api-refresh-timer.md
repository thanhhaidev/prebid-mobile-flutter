---
status: accepted
date: 2026-10-10
---

# Android Original API auto-refresh is a plugin timer

On iOS the Original API ad units use Prebid's own auto-refresh. Prebid Android 3.4's `PrebidAdUnit` can't refresh: it rebuilds its inner ad unit with interval 0 and no refresh listener on every `fetchDemand`. So on Android `MultiformatAdHostApiImpl.kt` re-runs the same request on a main-thread timer, clamped to Prebid's 30–120 s bounds, and sends each result to Dart through `MultiformatFlutterApi.onDemandRefreshed` (a separate Flutter API, since a Pigeon reply is sent only once). The timer stops when Dart has no handler for the ad any more, e.g. after a hot restart.

## Consequences

- `setAutoRefreshInterval`, `stopAutoRefresh` and `resumeAutoRefresh` behave the same on both platforms; the bounds are documented as 30–120 s on both.
- If ADR-0007 moves single-format units to Prebid's legacy `AdUnit` classes, whose refresh may work, this timer may only be needed for true multiformat requests; verify before removing it.
