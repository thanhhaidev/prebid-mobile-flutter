import 'package:flutter/material.dart';

import '../../demo/demo_screen.dart' show DemoScaffold;
import '../../services/bid_inspector.dart';
import '../../widgets/plain_list_row.dart';
import 'about_page.dart';
import 'bid_inspector_page.dart';
import 'log_page.dart';
import 'sdk_settings_page.dart';
import 'targeting_data_page.dart';

/// Utilities → "Developer tools": the Flutter example's extras, kept out of
/// the original structure — SDK settings overrides, Bid Inspector, the last
/// bid response, targeting data, the event log and plugin info.
class DeveloperToolsPage extends StatelessWidget {
  const DeveloperToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    void push(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));

    return DemoScaffold(
      title: 'Developer tools',
      progressOverlay: false,
      child: ListView(
        children: [
          PlainListRow(
            label: 'SDK settings',
            onTap: () => push(const SettingsPage()),
          ),
          PlainListRow(
            label: 'Bid Inspector',
            onTap: () => push(const BidInspectorPage()),
          ),
          PlainListRow(
            label: 'Last bid response',
            onTap: () {
              final latest = BidInspector.instance.latest;
              if (latest == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No bid response captured yet')),
                );
                return;
              }
              push(BidRecordPage(record: latest));
            },
          ),
          PlainListRow(
            label: 'Targeting Data',
            onTap: () => push(const TargetingDataPage()),
          ),
          PlainListRow(label: 'Event log', onTap: () => push(const LogPage())),
          PlainListRow(label: 'About', onTap: () => push(const AboutPage())),
        ],
      ),
    );
  }
}
