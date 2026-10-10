import 'package:flutter/material.dart';

import '../data/demo_item.dart';
import 'families/banner_family.dart';
import 'families/fullscreen_family.dart';
import 'families/mediation_family.dart';
import 'families/native_family.dart';
import 'families/special_family.dart';
import 'screens/in_app_banner_screen.dart';
import 'screens/placeholder_screen.dart';

/// Maps a [DemoItem] to its screen — the original nav-graph actions.
///
/// Each screen family (`families/*_family.dart`) owns its routing: it returns
/// the screen for the items it handles, matching on [DemoItem.screen] and,
/// where one layout has per-integration fragments, [DemoItem.integration].
/// Unmatched items open [PlaceholderScreen].
Widget buildDemoScreen(DemoItem item) {
  if (item.screen == ScreenType.a1 &&
      item.integration == DemoIntegration.inApp) {
    return InAppBannerScreen(item: item);
  }
  return buildSpecialScreen(item) ??
      buildBannerScreen(item) ??
      buildFullscreenScreen(item) ??
      buildNativeScreen(item) ??
      buildMediationScreen(item) ??
      PlaceholderScreen(item: item);
}

/// Pushes [item]'s screen on the current (tab) navigator.
Future<void> openDemo(BuildContext context, DemoItem item) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => buildDemoScreen(item),
        settings: RouteSettings(name: item.label),
      ),
    );
