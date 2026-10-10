import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../demo_screen.dart';

/// Temporary screen for screen types that are not implemented yet: shows the
/// item's registry data and "Screen type X — coming next". Replace the route
/// in `lib/demo/demo_router.dart` when the real screen lands.
class PlaceholderScreen extends StatelessWidget {
  final DemoItem item;

  const PlaceholderScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final c = DemoColors.of(context);
    final rows = <(String, String)>[
      ('Screen', '${item.screen.code} — ${item.screen.description}'),
      ('Integration', item.integration.label),
      ('Category', item.category.label),
      (
        'Config id',
        item.randomConfigIds != null
            ? 'random: ${item.randomConfigIds!.join(' | ')}'
            : item.configId ?? '—',
      ),
      if (item.adUnitId != null) ('Ad unit', item.adUnitId!),
      ('Size', item.size.toString()),
      if (item.additionalSizes != null)
        (
          'Additional sizes',
          item.additionalSizes!
              .map((s) => '${s.width.toInt()}x${s.height.toInt()}')
              .join(', '),
        ),
      if (item.refreshSeconds != null) ('Refresh', '${item.refreshSeconds} s'),
      if (item.adFormats != null)
        ('Formats', item.adFormats!.map((f) => f.name).join(', ')),
      if (item.minSizePercentage != null)
        (
          'Min size %',
          '${item.minSizePercentage!.width.toInt()}x'
              '${item.minSizePercentage!.height.toInt()}',
        ),
      if (item.accountId != null) ('Account', item.accountId!),
      if (item.serverUrl != null) ('Server', item.serverUrl!),
      if (item.customFormatId != null)
        ('Custom format id', item.customFormatId!),
      if (item.appName != null) ('App name', item.appName!),
      if (item.flags.isNotEmpty)
        ('Flags', item.flags.map((f) => f.name).join(', ')),
      if (item.configuratorMode != null)
        ('Configurator', item.configuratorMode!.name),
      if (item.pendingApis.isNotEmpty)
        ('Pending APIs', item.pendingApis.join(', ')),
      if (item.note != null) ('Note', item.note!),
    ];
    return DemoScaffold(
      title: item.label,
      progressOverlay: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.mint,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: c.primary.withValues(alpha: 0.4)),
            ),
            child: Text(
              'Screen type ${item.screen.code} — coming next',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation.weight(700)],
                color: c.primaryStrong,
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(k, style: TextStyle(color: c.muted)),
                  ),
                  Expanded(
                    child: SelectableText(
                      v,
                      style: AppFonts.monoStyle(fontSize: 12.5, color: c.text),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
