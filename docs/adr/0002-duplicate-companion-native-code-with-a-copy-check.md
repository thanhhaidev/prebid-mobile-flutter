---
status: accepted
date: 2026-10-10
---

# Companion native code is shared as identical copies checked by tool/check_copies.sh

The three companion packages parse the same channel arguments natively (native assets and trackers, request options, fullscreen controls, video parameters) and share presenting and error-formatting helpers. That code lives in `PrebidRequests.kt` and `PrebidRequests.swift`, one copy in each companion; the Kotlin copies differ only in their `package` line. `tool/check_copies.sh`, run by `melos run analyze` and CI, fails when a copy drifts. Each package's own helpers stay in `PrebidShared.kt` / `.swift`, which are not copies.

A pub package can't reliably compile against another Flutter plugin's native sources on both platforms: on Android each plugin is its own Gradle module with no declared dependency on a sibling, and on iOS the code would have to resolve the same way through CocoaPods and through Swift Package Manager, both of which the packages support. A separate native library published to Maven and CocoaPods / SPM would be a fifth artifact with its own release cycle for a few hundred lines. Copies plus a check keep each package self-contained and stop the drift that happened before (the companions once handled `imageMimes` differently).

The same script keeps the other files that can't be shared across published packages identical: every package's `analysis_options.yaml` lint rules and the companions' `test/channel_harness.dart`.

## Consequences

- A change to the shared parsing is made in all three packages at once, or the check fails.
