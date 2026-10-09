import 'package:flutter/rendering.dart';

/// The fraction (0–1) of [box]'s area that Flutter paints on screen.
///
/// The box is clipped by every ancestor's paint clip (scroll viewports,
/// `ClipRect`, …) and by the view. Native code can't see these clips: Flutter
/// applies them to a platform view as a mask. So the native viewability check
/// of a native ad also requires this fraction (sent by `PrebidNativeAdView`).
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
