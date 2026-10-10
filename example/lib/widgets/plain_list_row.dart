import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A plain one-label list row (the original `simple_list_item`), with a
/// bottom divider.
class PlainListRow extends StatelessWidget {
  const PlainListRow({super.key, required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = DemoColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        child: Text(label, style: TextStyle(fontSize: 15, color: c.text)),
      ),
    );
  }
}
