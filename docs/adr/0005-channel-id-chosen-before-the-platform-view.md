---
status: accepted
date: 2026-10-10
---

# Platform views get a channel ID chosen in Dart before the view exists

A native ad view starts loading as soon as it is created, which can be before Flutter's `onPlatformViewCreated` runs. A method channel named after the platform view ID could only be listened on from that callback, so early events (an immediate failure, for example) were lost.

Instead the widget creates an `AdViewChannel` first: it takes a fresh channel ID, starts listening on `<prefix>_<channelId>`, and passes the ID to the native view as the `channelId` creation parameter; the native view names its channel after it (falling back to the view ID when the parameter is absent). The core's banner and native views and every companion platform view use it, which is why `AdViewChannel` is part of the companion library (ADR-0006).

## Consequences

- A new view needs a new `AdViewChannel`; disposing one stops listening.
- Channel IDs are a Dart-side counter, separate from the ad IDs that route events of fullscreen ads and Pigeon ads.
