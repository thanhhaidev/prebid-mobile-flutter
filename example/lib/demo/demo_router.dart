import 'package:flutter/material.dart';

import '../data/demo_item.dart';
import 'families/banner_family.dart';
import 'families/fullscreen_family.dart';
import 'families/mediation_family.dart';
import 'families/native_family.dart';
import 'families/special_family.dart';

/// Maps a [DemoItem] to its screen — the original nav-graph actions.
///
/// Each screen family (`families/*_family.dart`) owns its routing: it returns
/// the screen for the items it handles, matching on [DemoItem.screen] and,
/// where one layout has per-integration fragments, [DemoItem.integration].
/// Every item has a screen (`test/demo_router_test.dart`); an unmatched one
/// is a programming error.
Widget buildDemoScreen(DemoItem item) {
  return buildSpecialScreen(item) ??
      buildBannerScreen(item) ??
      buildFullscreenScreen(item) ??
      buildNativeScreen(item) ??
      buildMediationScreen(item) ??
      (throw StateError('No screen for $item'));
}

/// Pushes [item]'s screen on the current (tab) navigator.
Future<void> openDemo(BuildContext context, DemoItem item) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => buildDemoScreen(item),
        settings: RouteSettings(name: item.label),
      ),
    );
