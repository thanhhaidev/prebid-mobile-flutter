import 'package:flutter/material.dart';

import '../utils/logger.dart';

/// Expandable log viewer panel — shows SDK event log with timestamps.
class LogViewerPanel extends StatelessWidget {
  const LogViewerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PrebidDemoLogger.instance,
      builder: (context, _) {
        final entries = PrebidDemoLogger.instance.entries;
        return ExpansionTile(
          title: Row(
            children: [
              const Icon(Icons.terminal, size: 16),
              const SizedBox(width: 6),
              Text('Event Log (${entries.length})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: EdgeInsets.zero,
          children: [
            if (entries.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.clear_all, size: 14),
                  label: const Text('Clear', style: TextStyle(fontSize: 11)),
                  onPressed: PrebidDemoLogger.instance.clear,
                ),
              ),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: entries.length,
                reverse: true,
                itemBuilder: (_, i) {
                  final e = entries[entries.length - 1 - i];
                  final color = switch (e.level) {
                    LogLevel.error => Colors.red.shade700,
                    LogLevel.warning => Colors.orange.shade700,
                    LogLevel.info => Colors.blueGrey.shade700,
                    LogLevel.debug => Colors.grey.shade600,
                  };
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '${e.timeString} ',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500,
                              fontFamily: 'monospace'),
                        ),
                        TextSpan(
                          text: '[${e.tag}] ',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold,
                              color: color, fontFamily: 'monospace'),
                        ),
                        TextSpan(
                          text: e.message,
                          style: TextStyle(
                              fontSize: 10, color: color,
                              fontFamily: 'monospace'),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
