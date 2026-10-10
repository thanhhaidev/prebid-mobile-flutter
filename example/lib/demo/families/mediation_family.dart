import 'package:flutter/widgets.dart';

import '../../data/demo_item.dart';
import '../screens/mediation/mediation_screens.dart';

/// Screens of the mediation family: AdMob G1–G4 and MAX H1–H4. Returns `null`
/// for items this family doesn't handle; [buildDemoScreen] then tries the
/// next family.
Widget? buildMediationScreen(DemoItem item) {
  return switch (item.screen) {
    ScreenType.g1 || ScreenType.h1 => MediationBannerScreen(item: item),
    ScreenType.g2 ||
    ScreenType.g3 ||
    ScreenType.h2 ||
    ScreenType.h3 => MediationFullscreenScreen(item: item),
    ScreenType.g4 || ScreenType.h4 => MediationNativeScreen(item: item),
    _ => null,
  };
}
