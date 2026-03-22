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

/// Displays event counters for ad callbacks.
class EventCounterList extends StatelessWidget {
  final EventTracker tracker;
  final List<String> events;
  const EventCounterList({super.key, required this.tracker, required this.events});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...events.map((e) {
          final c = tracker.count(e);
          final d = tracker.delta(e);
          final isError = e.toLowerCase().contains('fail');
          final hasCount = c > 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$e called',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasCount ? FontWeight.bold : FontWeight.normal,
                      color: hasCount
                          ? (isError ? Colors.red.shade700 : Colors.green.shade700)
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
                Text(
                  '-  $c (+$d)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasCount ? FontWeight.bold : FontWeight.normal,
                    color: hasCount
                        ? (isError ? Colors.red.shade700 : Colors.green.shade700)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }),
        if (tracker.lastError != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text('Error: ${tracker.lastError}',
                style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
          ),
      ],
    );
  }
}
