import 'package:flutter/material.dart';

import '../models/demo_ad_category.dart';

/// Icon + accent colour for each ad category, used for list avatars and
/// detail-page headers so the app reads as one consistent system.
({IconData icon, Color color}) styleFor(DemoAdCategory c) => switch (c) {
  DemoAdCategory.all => (
    icon: Icons.apps_rounded,
    color: const Color(0xFF64748B),
  ),
  DemoAdCategory.banner => (
    icon: Icons.crop_16_9_rounded,
    color: const Color(0xFF2563EB),
  ),
  DemoAdCategory.interstitial => (
    icon: Icons.fullscreen_rounded,
    color: const Color(0xFF7C3AED),
  ),
  DemoAdCategory.mraid => (
    icon: Icons.touch_app_rounded,
    color: const Color(0xFF0D9488),
  ),
  DemoAdCategory.video => (
    icon: Icons.play_circle_rounded,
    color: const Color(0xFFDC2626),
  ),
  DemoAdCategory.native => (
    icon: Icons.view_agenda_rounded,
    color: const Color(0xFF059669),
  ),
};

/// A rounded square avatar showing the category's icon over a tinted surface.
class CategoryAvatar extends StatelessWidget {
  final DemoAdCategory category;
  final double size;
  const CategoryAvatar({super.key, required this.category, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final s = styleFor(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(s.icon, color: s.color, size: size * 0.5),
    );
  }
}
