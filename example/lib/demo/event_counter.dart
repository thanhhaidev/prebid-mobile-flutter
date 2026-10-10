import 'package:flutter/material.dart';

import '../services/logger.dart';
import '../theme/app_theme.dart';

/// State of one event row — the original `EventCounterView`.
class EventCounterState {
  /// Fires since the screen opened (never reset).
  int total = 0;

  /// Fires since the row was last acknowledged / reset.
  int delta = 0;

  /// Highlighted (fired and not yet acknowledged).
  bool enabled = false;
}

/// The event rows of one demo screen, in display order.
///
/// Mirrors the original semantics (spec §1.2):
/// - initial `0 ( 0 )`, row greyed (disabled);
/// - [fire]: enabled, total++, delta++ (shown as `+N`);
/// - tapping a row ([acknowledge]) disables it: delta → 0, total kept;
/// - [reset] (`resetEventButtons()`) disables rows the same way — totals
///   persist for the screen's lifetime.
///
/// Every fire is also written to the developer-tools log.
class EventCounters extends ChangeNotifier {
  EventCounters(this.labels, {this.tag = 'Ad'})
    : _states = {for (final l in labels) l: EventCounterState()};

  /// Row labels, in display order (exact original strings).
  final List<String> labels;

  /// Tag for the developer-tools log.
  final String tag;

  final Map<String, EventCounterState> _states;

  /// The original `resetEventButtons()` row set.
  static const standardRows = {
    'onAdFailed called',
    'onAdLoaded called',
    'onAdImpression',
    'onAdClicked called',
    'onAdDisplayed called',
    'onAdClosed called',
    'onAdExpired',
  };

  EventCounterState operator [](String label) =>
      _states[label] ?? (throw ArgumentError('Unknown event row "$label"'));

  /// Lights [label] (total++, delta++). [detail] (error message, reward, ...)
  /// only goes to the log.
  void fire(String label, [String? detail]) {
    final s = this[label];
    s
      ..enabled = true
      ..total += 1
      ..delta += 1;
    final failed = label.toLowerCase().contains('fail');
    PrebidDemoLogger.instance.log(
      tag,
      detail == null ? label : '$label: $detail',
      level: failed ? LogLevel.error : LogLevel.info,
    );
    notifyListeners();
  }

  /// Tap on a row: disable it (delta → 0, total kept).
  void acknowledge(String label) {
    final s = this[label];
    s
      ..enabled = false
      ..delta = 0;
    notifyListeners();
  }

  /// Disables [only] rows, or the [standardRows] present on this screen
  /// (`resetEventButtons()`); totals persist.
  void reset({Iterable<String>? only}) {
    final targets = only ?? labels.where(standardRows.contains);
    for (final l in targets) {
      _states[l]
        ?..enabled = false
        ..delta = 0;
    }
    notifyListeners();
  }
}

/// All rows of [counters], top to bottom.
class EventCounterList extends StatelessWidget {
  const EventCounterList({super.key, required this.counters});
  final EventCounters counters;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: counters,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final label in counters.labels)
            EventCounterRow(
              label: label,
              state: counters[label],
              onTap: () => counters.acknowledge(label),
            ),
        ],
      ),
    );
  }
}

/// One row: `"<label>  -  <total> ( +<delta> )"`, JetBrains Mono. Greyed
/// while disabled, highlighted (mint background, orange accent) once fired.
class EventCounterRow extends StatelessWidget {
  const EventCounterRow({
    super.key,
    required this.label,
    required this.state,
    this.onTap,
  });
  final String label;
  final EventCounterState state;
  final VoidCallback? onTap;

  /// The row text, e.g. `onAdLoaded called  -  3 ( +1 )`.
  static String format(String label, EventCounterState s) =>
      '$label  -  ${s.total} ( ${s.delta > 0 ? '+${s.delta}' : '0'} )';

  @override
  Widget build(BuildContext context) {
    final c = DemoColors.of(context);
    final enabled = state.enabled;
    final failed = label.toLowerCase().contains('fail');
    final accent = failed ? c.danger : c.primaryStrong;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: enabled ? (failed ? c.dangerBg : c.mint) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: enabled ? accent.withValues(alpha: 0.45) : c.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled ? accent : Colors.transparent,
                    border: Border.all(
                      color: enabled ? accent : c.muted.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    format(label, state),
                    style: AppFonts.monoStyle(
                      fontWeight: enabled ? FontWeight.w700 : FontWeight.w400,
                      color: enabled ? accent : c.muted.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
