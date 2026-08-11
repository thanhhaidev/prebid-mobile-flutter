import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/demo_ad_category.dart';
import '../utils/category_style.dart';

/// A header card for detail pages: category avatar, the "AD UNIT" label, the
/// config id (monospace), and a tap-to-copy action.
class AdUnitHeader extends StatelessWidget {
  final String configId;
  final DemoAdCategory category;

  const AdUnitHeader({
    super.key,
    required this.configId,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CategoryAvatar(category: category),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AD UNIT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  configId,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.copy_rounded, size: 18, color: theme.colorScheme.outline),
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: configId));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied: $configId'),
                  duration: const Duration(milliseconds: 900),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
