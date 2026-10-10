import 'package:flutter/material.dart';

import '../widgets/plain_list_row.dart';
import 'app_settings_page.dart';
import 'developer_tools/developer_tools_page.dart';
import 'iab_consent_settings_page.dart';
import 'versions_page.dart';

/// The Utilities tab — the original `UtilitiesListFragment` (exactly
/// "IAB Consent Settings", "App settings", "Versions") plus the Flutter
/// example's extra "Developer tools" entry at the end.
class UtilitiesPage extends StatelessWidget {
  const UtilitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <(String, Widget Function())>[
      ('IAB Consent Settings', () => const IabConsentSettingsPage()),
      ('App settings', () => const AppSettingsPage()),
      ('Versions', () => const VersionsPage()),
      ('Developer tools', () => const DeveloperToolsPage()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Utilities')),
      body: ListView(
        children: [
          for (final (label, page) in entries)
            PlainListRow(
              label: label,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => page())),
            ),
        ],
      ),
    );
  }
}
