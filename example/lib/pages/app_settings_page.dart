import 'package:flutter/material.dart';

import '../demo/demo_screen.dart' show DemoScaffold;
import '../services/app_settings.dart';
import '../widgets/section_header.dart';

/// Utilities → "App settings" (title "App Settings") — the original
/// `AppSettingsFragment` (spec §4.1). Its only setting: "Show Progress
/// Dialog", which adds a full-screen progress overlay to every demo screen.
class AppSettingsPage extends StatelessWidget {
  const AppSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'App Settings',
      progressOverlay: false,
      child: ListView(
        children: [
          const SectionHeader('Progress dialog Settings'),
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.showProgressDialogNotifier,
            builder: (context, value, _) => SwitchListTile(
              title: const Text('Show Progress Dialog'),
              value: value,
              onChanged: AppSettings.setShowProgressDialog,
            ),
          ),
        ],
      ),
    );
  }
}
