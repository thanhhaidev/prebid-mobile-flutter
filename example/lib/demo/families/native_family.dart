import 'package:flutter/widgets.dart';

import '../../data/demo_item.dart';
import '../screens/native/native_screens.dart';

/// Screens of the native family: C1, C2, C3 and the native feeds of F.
/// Returns `null` for items this family doesn't handle; [buildDemoScreen]
/// then tries the next family.
Widget? buildNativeScreen(DemoItem item) {
  return switch (item.screen) {
    ScreenType.c1 || ScreenType.c3 => InAppNativeScreen(item: item),
    ScreenType.c2 => GamNativeScreen(item: item),
    ScreenType.f when item.category == DemoCategory.native => NativeFeedScreen(
      item: item,
    ),
    _ => null,
  };
}
