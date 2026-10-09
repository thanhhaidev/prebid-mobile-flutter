import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_settings.dart';
import '../utils/bid_inspector.dart';

/// Lists every Prebid Server request / response pair captured through
/// `PrebidEventDelegate` ([BidInspector]); tap one for the full JSON.
class BidInspectorPage extends StatelessWidget {
  const BidInspectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final inspector = BidInspector.instance;
    return ListenableBuilder(
      listenable: inspector,
      builder: (context, _) {
        final records = inspector.records;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Bid Inspector'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                tooltip: 'Clear',
                onPressed: records.isEmpty ? null : inspector.clear,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              SwitchListTile(
                title: const Text('Capture bid requests'),
                subtitle: const Text(
                  'PrebidMobile.setEventListener (PrebidEventDelegate)',
                  style: TextStyle(fontSize: 12),
                ),
                value: inspector.enabled,
                onChanged: (v) {
                  AppSettings.setBidInspector(v);
                  inspector.setEnabled(v);
                },
              ),
              const Divider(),
              if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No bid requests captured yet')),
                ),
              for (final r in records) _RecordTile(record: r),
            ],
          ),
        );
      },
    );
  }
}

class _RecordTile extends StatelessWidget {
  final BidRecord record;
  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bids = record.bids;
    final status = record.failed
        ? 'no response'
        : bids.isEmpty
        ? 'no bids'
        : '${bids.length} bid${bids.length == 1 ? '' : 's'}: '
              '${bids.map((b) => '${b.$1} ${b.$2 ?? ''}'.trim()).join(', ')}';
    final color = record.failed || bids.isEmpty
        ? theme.colorScheme.error
        : const Color(0xFF16A34A);
    final t = record.time;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(Icons.swap_vert_rounded, color: color),
        title: Text(
          record.configIds.join(', '),
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        ),
        subtitle: Text(
          '$time · ${record.formats.join('+')} · $status',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BidRecordPage(record: record)),
        ),
      ),
    );
  }
}

/// Request / response JSON of one [BidRecord].
class BidRecordPage extends StatelessWidget {
  final BidRecord record;
  const BidRecordPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final request = BidRecord.pretty(record.request);
    final response = BidRecord.pretty(record.response);
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Bid Request'),
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'Request'),
                Tab(text: 'Response'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Copy',
                onPressed: () {
                  final index = DefaultTabController.of(context).index;
                  Clipboard.setData(
                    ClipboardData(text: index == 0 ? request : response),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          body: TabBarView(children: [_JsonView(request), _JsonView(response)]),
        ),
      ),
    );
  }
}

class _JsonView extends StatelessWidget {
  final String text;
  const _JsonView(this.text);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        text,
        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
      ),
    );
  }
}
