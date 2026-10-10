import 'package:flutter/widgets.dart';

import '../../data/demo_item.dart';
import '../screens/fullscreen/fullscreen_screen.dart';

/// Screens of the fullscreen family: B1 (interstitial) and B2 (rewarded) for
/// In-App, GAM, GAM Original and the memory-leak interstitials. Returns `null`
/// for items this family doesn't handle; [buildDemoScreen] then tries the
/// next family.
Widget? buildFullscreenScreen(DemoItem item) {
  return switch (item.screen) {
    ScreenType.b1 || ScreenType.b2 => FullscreenScreen(item: item),
    _ => null,
  };
}
