import 'package:flutter/material.dart';

import '../../utils/logger.dart';

/// App-wide log of SDK setup and ad callbacks ([PrebidDemoLogger]).
class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = PrebidDemoLogger.instance;
    return ListenableBuilder(
      listenable: logger,
      builder: (context, _) {
        final entries = logger.entries.reversed.toList();
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Logs'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                tooltip: 'Clear',
                onPressed: entries.isEmpty ? null : logger.clear,
              ),
            ],
          ),
          body: entries.isEmpty
              ? const Center(child: Text('No log entries'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    final color = switch (e.level) {
                      LogLevel.error => theme.colorScheme.error,
                      LogLevel.warning => Colors.orange,
                      _ => theme.colorScheme.onSurface,
                    };
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${e.timeString}  ',
                              style: TextStyle(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            TextSpan(
                              text: '[${e.tag}] ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: e.message,
                              style: TextStyle(color: color),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
