---
status: accepted
date: 2026-10-10
---

# Pigeon for the core plugin, plain method channels for the companion packages

The core package talks to its native code through Pigeon (`packages/prebid_mobile_sdk/pigeons/prebid_api.dart`): typed host APIs for configuration, targeting and every ad type, and Flutter APIs for events. Its platform views (banner, native) add one method channel per view. The companion packages (GAM, AdMob, MAX) use plain `MethodChannel`s and platform views only, with map payloads.

Pigeon generates its Kotlin classes into the core's own Android package and its Swift types into the core's own module. A companion is a separate Flutter plugin whose native module neither depends on nor sees the core's native module, so it can't reuse those generated types or host-API handlers. Its own Pigeon file would duplicate the core's data classes (native assets, video parameters, fullscreen controls) in three more schemas, each with its own generate and drift check. The companion surface is small (load / show / destroy and a handful of events per format), so maps are cheaper: the core's value types serialize themselves with `toMap()` (`NativeParameters`, `VideoParameters`, `PrebidFullscreenControls`), and the native side parses them once per companion (see ADR-0002).

## Consequences

- The core has compile-time-checked channels; the companions rely on `toMap()` keys matching the native parsing, covered by each companion's channel-harness tests.
- Companion events carry an ad ID or arrive on a per-view channel (ADR-0005); the Dart routing they share lives in the core's companion library (ADR-0006).
