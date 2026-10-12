import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The fraction (0–1) of [box]'s area that Flutter paints on screen.
///
/// The box is clipped by every ancestor's paint clip (scroll viewports,
/// `ClipRect`, …) and by the view, and is invisible under an ancestor that
/// doesn't paint it (`Offstage`, `Opacity` 0, an `IndexedStack`'s other
/// children). Native code can't see these: Flutter applies them to a
/// platform view as a mask, or keeps the view composited. So the native
/// viewability check of a native ad also requires this fraction.
///
/// All rects are mapped into the root's coordinate space; the result is a
/// ratio of areas, so the space's scale doesn't matter.
double visibleFraction(RenderBox box) {
  if (!box.attached || !box.hasSize || box.size.isEmpty) return 0;
  Rect toRoot(RenderObject object, Rect rect) =>
      MatrixUtils.transformRect(object.getTransformTo(null), rect);

  final full = toRoot(box, Offset.zero & box.size);
  if (full.isEmpty) return 0;
  var visible = full;
  RenderObject child = box;
  for (var parent = box.parent; parent != null; parent = parent.parent) {
    if (!parent.paintsChild(child) || _hiddenInIndexedStack(parent, child)) {
      return 0;
    }
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) visible = visible.intersect(toRoot(parent, clip));
    // The view's bounds: the root's child covers the whole view.
    if (parent is RenderView && child is RenderBox) {
      visible = visible.intersect(toRoot(child, Offset.zero & child.size));
    }
    if (visible.width <= 0 || visible.height <= 0) return 0;
    child = parent;
  }
  final fraction =
      (visible.width * visible.height) / (full.width * full.height);
  return fraction.clamp(0.0, 1.0);
}

/// An `IndexedStack` paints only its child at `index`, without saying so in
/// `paintsChild`.
bool _hiddenInIndexedStack(RenderObject parent, RenderObject child) {
  if (parent is! RenderIndexedStack) return false;
  final index = parent.index;
  if (index == null) return true;
  var shown = parent.firstChild;
  for (var i = 0; i < index && shown != null; i++) {
    shown = parent.childAfter(shown);
  }
  return !identical(shown, child);
}

/// Sends a native ad view the fraction of it Flutter paints on screen
/// ([visibleFraction], two decimals) as `setVisibleFraction`, polled as the
/// native viewability checks poll and sent when it changes.
///
/// A widget whose tickers are muted (a route under an opaque one) counts as
/// invisible: the overlay keeps painting it, offstage.
class VisibleFractionReporter {
  static const _interval = Duration(milliseconds: 250);

  Timer? _timer;
  double? _sent;

  /// Polls [context]'s render box (none while [context] returns null) and
  /// sends to [channel]; stops any earlier polling first.
  void start(MethodChannel channel, BuildContext? Function() context) {
    stop();
    _timer = Timer.periodic(_interval, (_) {
      final ctx = context();
      final box = ctx != null && ctx.mounted ? ctx.findRenderObject() : null;
      if (ctx == null || box is! RenderBox) return;
      final fraction = TickerMode.getValuesNotifier(ctx).value.enabled
          ? (visibleFraction(box) * 100).roundToDouble() / 100
          : 0.0;
      if (fraction == _sent) return;
      _sent = fraction;
      channel.invokeMethod<void>('setVisibleFraction', fraction).catchError((
        Object _,
      ) {
        // The native view is gone (disposed between ticks).
      });
    });
  }

  /// Stops polling; the next [start] sends its first fraction again.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _sent = null;
  }
}
