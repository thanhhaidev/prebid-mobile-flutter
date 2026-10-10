import 'package:flutter/widgets.dart';

import '../../data/demo_item.dart';
import '../screens/banner/banner_layouts.dart';
import '../screens/banner/banner_screen.dart';

/// Screens of the banner family: A1 (except In-App, which has its own
/// screen), A2, A3, A4, A5, A6, E and the video feeds of F. Returns `null`
/// for items this family doesn't handle; [buildDemoScreen] then tries the
/// next family.
Widget? buildBannerScreen(DemoItem item) {
  return switch (item.screen) {
    ScreenType.a1 ||
    ScreenType.a2 ||
    ScreenType.a5 ||
    ScreenType.a6 => BannerScreen(item: item),
    ScreenType.a3 => ReusableBannerScreen(item: item),
    ScreenType.a4 => RecyclerBannerScreen(item: item),
    ScreenType.e => BannersAndInterstitialScreen(item: item),
    ScreenType.f when item.category != DemoCategory.native => VideoFeedScreen(
      item: item,
    ),
    _ => null,
  };
}
