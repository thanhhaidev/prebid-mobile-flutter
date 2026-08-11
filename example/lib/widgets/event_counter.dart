import 'package:flutter/material.dart';

/// Tracks ad event callback counts and errors.
///
/// Mirrors the event tracking pattern in Prebid's demo app,
/// showing counts like "onAdLoaded called - 1 (+1)".
class EventTracker extends ChangeNotifier {
  final Map<String, int> _counts = {};
  final Map<String, int> _deltas = {};
  String? lastError;

  void track(String event, [String? error]) {
    _counts[event] = (_counts[event] ?? 0) + 1;
    _deltas[event] = (_deltas[event] ?? 0) + 1;
    if (error != null) lastError = error;
    notifyListeners();
  }

  int count(String event) => _counts[event] ?? 0;
  int delta(String event) => _deltas[event] ?? 0;

  void reset() {
    _counts.clear();
    _deltas.clear();
    lastError = null;
    notifyListeners();
  }
}

/// A card of callback counters — one row per event with a status dot, the
/// event name, and a count pill. Triggered rows light up (green, or red for
/// failures); untriggered rows stay muted.
class EventCounterList extends StatelessWidget {
  final EventTracker tracker;
  final List<String> events;
  const EventCounterList({
    super.key,
    required this.tracker,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (int i = 0; i < events.length; i++) ...[
            if (i > 0) Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.4)),
            _row(theme, events[i]),
          ],
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String event) {
    final c = tracker.count(event);
    final d = tracker.delta(event);
    final active = c > 0;
    final isFail = event.toLowerCase().contains('fail');
    final accent = isFail ? theme.colorScheme.error : const Color(0xFF16A34A);
    final muted = theme.colorScheme.outlineVariant;
    final color = active ? accent : muted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: active ? accent : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              event,
              style: TextStyle(
                fontSize: 14,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (active && d > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '+$d',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: active
                  ? accent.withValues(alpha: 0.12)
                  : muted.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$c',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
