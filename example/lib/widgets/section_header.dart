import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Uppercase section header (settings pages).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = DemoColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: AppFonts.monoStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: c.primaryStrong,
        ).copyWith(letterSpacing: 1.2),
      ),
    );
  }
}
