import 'dart:async';

import '../prebid_mobile.dart';

bool _released = false;

/// Releases the native ads of an earlier Dart isolate of this engine, once,
/// before this isolate's first ad.
///
/// After a hot restart the native side still holds the previous isolate's
/// ads: auto-refresh timers keep running auctions, and the restarted ad id
/// counters reuse their ids. None of them can belong to this isolate yet.
/// Best effort: a failure (e.g. no plugin in a test) only skips the cleanup.
void releasePreviousIsolateAds() {
  if (_released) return;
  _released = true;
  try {
    // The same channel the rest of the package uses (tests swap it).
    unawaited(prebidMobileHostApi().releaseAds().catchError((Object _) {}));
  } catch (_) {
    // Not registered (tests without a host API stub).
  }
}
