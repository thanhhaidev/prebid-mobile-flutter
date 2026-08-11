import 'package:flutter/material.dart';

import 'about_page.dart';
import 'consent_settings_page.dart';
import 'original_api_page.dart';
import 'settings_page.dart';
import 'targeting_data_page.dart';

/// Utilities tab — consent, app settings, targeting data, and versions.
class UtilitiesPage extends StatelessWidget {
  const UtilitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilities')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _tile(
            context,
            icon: Icons.privacy_tip_rounded,
            color: const Color(0xFF7C3AED),
            title: 'IAB Consent Settings',
            subtitle: 'GDPR (TCF) & CCPA (US Privacy)',
            page: const ConsentSettingsPage(),
          ),
          _tile(
            context,
            icon: Icons.tune_rounded,
            color: const Color(0xFF2563EB),
            title: 'App Settings',
            subtitle: 'Server, account, log level, debug',
            page: const SettingsPage(),
          ),
          _tile(
            context,
            icon: Icons.data_object_rounded,
            color: const Color(0xFF0D9488),
            title: 'Targeting Data',
            subtitle: 'Keywords, ext data, ORTB config',
            page: const TargetingDataPage(),
          ),
          _tile(
            context,
            icon: Icons.ads_click_rounded,
            color: const Color(0xFFEA580C),
            title: 'Original API (GAM)',
            subtitle: 'Hand Prebid keywords to google_mobile_ads',
            page: const OriginalApiPage(),
          ),
          _tile(
            context,
            icon: Icons.info_rounded,
            color: const Color(0xFF64748B),
            title: 'Versions',
            subtitle: 'SDK & plugin info',
            page: const AboutPage(),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: theme.colorScheme.outline,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        ),
      ),
    );
  }
}
