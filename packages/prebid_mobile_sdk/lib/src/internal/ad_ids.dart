/// The next id of an ad the native side keys by id (interstitial, rewarded,
/// native, Original API, in-stream video). One counter for every kind: they
/// share the AdEventRouter channel, so ids must not collide across kinds.
int nextAdId() => _nextAdId++;

int _nextAdId = 1;
