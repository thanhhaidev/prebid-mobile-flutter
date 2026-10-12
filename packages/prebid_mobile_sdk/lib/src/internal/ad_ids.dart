import 'dart:math';

/// The next id of an ad the native side keys by id (interstitial, rewarded,
/// native, Original API, in-stream video). One counter for every kind: they
/// share the AdEventRouter channel, so ids must not collide across kinds.
int nextAdId() => _nextAdId++;

int _nextAdId = 1;

/// The first id of a counter whose ids name native objects that can outlive
/// a hot restart until the new isolate releases them (preloaded banners,
/// companion fullscreen ads): random, so the new isolate's ids don't reuse
/// a leftover object's id (and its channel) meanwhile. Below 2^31, which
/// Android reads some ids as.
int randomFirstId() => 1 + Random().nextInt(1 << 30);
