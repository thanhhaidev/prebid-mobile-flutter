import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/demo_ad_format.dart';
import '../models/test_case.dart';

/// Displays test case configuration info with copy-to-clipboard and optional
/// ad load timing.
class ConfigInfoPanel extends StatelessWidget {
  final TestCase tc;

  /// Optional ad load duration in milliseconds (shown if non-null).
  final int? loadTimeMs;

  const ConfigInfoPanel({super.key, required this.tc, this.loadTimeMs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: Theme.of(context).dividerColor.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _copyRow(context, 'Config ID', tc.configId),
          if (tc.storedResponse != null)
            _copyRow(context, 'Stored Response', tc.storedResponse!),
          _row('Format', tc.format.label),
          if (tc.format == DemoAdFormat.displayBanner ||
              tc.format == DemoAdFormat.videoBanner)
            _row('Size', '${tc.width}x${tc.height}'),
          if (loadTimeMs != null)
            _row('Load Time', '${loadTimeMs}ms',
                valueColor: loadTimeMs! < 2000
                    ? Colors.green.shade700
                    : Colors.orange.shade800),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: valueColor)),
          ),
        ],
      ),
    );
  }

  Widget _copyRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied: $value',
                      style: const TextStyle(fontSize: 11)),
                  duration: const Duration(milliseconds: 800),
                ),
              );
            },
            child: Icon(Icons.copy, size: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
