import 'package:flutter/material.dart';

import '../utils/logger.dart';

/// One fired callback, for the page's event log.
class AdEventEntry {
  final DateTime time;
  final String event;
  final String? detail;

  const AdEventEntry(this.time, this.event, this.detail);

  bool get isError => isErrorEvent(event);

  String get timeString =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}.'
      '${time.millisecond.toString().padLeft(3, '0')}';
}

/// Whether an event name reports a failure (shown in red).
bool isErrorEvent(String event) {
  final e = event.toLowerCase();
  return e.contains('fail') || e.contains('expired');
}

/// Tracks ad callback counts and a timestamped log of every callback.
///
/// Mirrors the event buttons of Prebid's `PrebidInternalTestApp`: each
/// callback row lights up with its count once it fires.
class EventTracker extends ChangeNotifier {
  /// Tag used for the app-wide [PrebidDemoLogger].
  final String tag;

  EventTracker([this.tag = 'Ad']);

  final Map<String, int> _counts = {};
  final List<AdEventEntry> _entries = [];

  /// Records [event] with an optional [detail] (error message, reward, ...).
  void track(String event, [String? detail]) {
    _counts[event] = (_counts[event] ?? 0) + 1;
    _entries.add(AdEventEntry(DateTime.now(), event, detail));
    PrebidDemoLogger.instance.log(
      tag,
      detail == null ? event : '$event: $detail',
      level: isErrorEvent(event) ? LogLevel.error : LogLevel.info,
    );
    notifyListeners();
  }

  int count(String event) => _counts[event] ?? 0;

  /// Oldest first.
  List<AdEventEntry> get entries => List.unmodifiable(_entries);

  void reset() {
    _counts.clear();
    _entries.clear();
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
            if (i > 0)
              Divider(
                height: 1,
                color: theme.dividerColor.withValues(alpha: 0.4),
              ),
            _row(theme, events[i]),
          ],
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String event) {
    final c = tracker.count(event);
    final active = c > 0;
    final isFail = isErrorEvent(event);
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

/// Chronological list of the callbacks fired on a detail page, with their
/// details (error messages, rewards, sizes).
class EventLogCard extends StatelessWidget {
  final EventTracker tracker;
  const EventLogCard({super.key, required this.tracker});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = tracker.entries.reversed.toList();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'EVENT LOG',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${entries.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Clear',
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                onPressed: entries.isEmpty ? null : tracker.reset,
              ),
            ],
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No callbacks yet',
                style: TextStyle(
                  color: theme.colorScheme.outline,
                  fontSize: 13,
                ),
              ),
            ),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.timeString,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: e.event,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: e.isError
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          if (e.detail != null)
                            TextSpan(
                              text: '  ${e.detail}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 12),
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
