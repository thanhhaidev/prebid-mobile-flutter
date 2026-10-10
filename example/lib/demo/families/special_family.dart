import 'package:flutter/widgets.dart';

import '../../data/demo_item.dart';
import '../screens/special/instream_screen.dart';
import '../screens/special/multiformat_screen.dart';
import '../screens/special/puc_screen.dart';

/// Screens of the special family: A2v (in-stream with the IMA player), D
/// (multiformat GAM Original) and T (Prebid Universal Creative testing). It
/// is tried first, so it only claims its own screen types.
Widget? buildSpecialScreen(DemoItem item) {
  return switch (item.screen) {
    ScreenType.a2v => InstreamScreen(item: item),
    ScreenType.d => MultiformatScreen(item: item),
    ScreenType.t => PucTestingScreen(item: item),
    _ => null,
  };
}
