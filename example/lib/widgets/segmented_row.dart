import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Equal-width segmented control (the original's 6-column segmented rows).
/// Selected segment: mint background, orange text — the docs menu's active
/// item.
class SegmentedRow<T> extends StatelessWidget {
  const SegmentedRow({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = DemoColors.of(context);
    return Container(
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) VerticalDivider(width: 1, color: c.border),
            Expanded(child: _segment(context, c, values[i])),
          ],
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, DemoColors c, T value) {
    final isSelected = value == selected;
    return Material(
      color: isSelected ? c.mint : Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(value),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                labelOf(value),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontVariations: [
                    FontVariation.weight(isSelected ? 700 : 500),
                  ],
                  color: isSelected ? c.primaryStrong : c.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
