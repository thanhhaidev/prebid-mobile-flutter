import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/demo_ad_category.dart';
import '../models/demo_integration.dart';
import '../utils/category_style.dart';

/// A header card for detail pages: category avatar, an integration chip, the
/// "AD UNIT" config id (monospace) and — for served/mediated integrations — the
/// ad-server ad unit id, each with a tap-to-copy action.
class AdUnitHeader extends StatelessWidget {
  final String configId;
  final DemoAdCategory category;
  final DemoIntegration? integration;
  final String? adUnitId;

  const AdUnitHeader({
    super.key,
    required this.configId,
    required this.category,
    this.integration,
    this.adUnitId,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryAvatar(category: category),
              const SizedBox(width: 12),
              Expanded(child: _field(context, 'CONFIG ID', configId)),
              if (integration != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    integration!.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              _copyButton(context, configId),
            ],
          ),
          if (adUnitId != null) ...[
            const Divider(height: 20),
            Row(
              children: [
                const SizedBox(width: 52),
                Expanded(child: _field(context, 'AD SERVER UNIT', adUnitId!)),
                _copyButton(context, adUnitId!),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _copyButton(BuildContext context, String value) {
    final theme = Theme.of(context);
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(Icons.copy_rounded, size: 18, color: theme.colorScheme.outline),
      tooltip: 'Copy',
      onPressed: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied: $value'),
            duration: const Duration(milliseconds: 900),
          ),
        );
      },
    );
  }
}
