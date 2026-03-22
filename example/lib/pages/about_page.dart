import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// About page — shows SDK, plugin, and platform information.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _pluginVersion = '0.0.1';
  static const _prebidSdkVersion = '2.x'; // Prebid Mobile SDK version
  static const _repoUrl =
      'https://github.com/thanhhaidev/prebid-mobile-flutter';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Logo / title
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.ads_click,
                    size: 36,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Prebid Flutter Demo',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'In-App Rendering Example',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Version info
          _infoCard(context, [
            _infoRow('Flutter Plugin', 'v$_pluginVersion'),
            _infoRow('Prebid Mobile SDK', _prebidSdkVersion),
            _infoRow('Flutter', Platform.version.split(' ').first),
            _infoRow('Dart', Platform.version.split(' ').first),
            _infoRow(
              'Platform',
              '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
            ),
          ]),
          const SizedBox(height: 16),

          // SDK Configuration
          _infoCard(context, [
            _infoRow('PBS Server', 'prebid-server-test-j.prebid.org'),
            _infoRow('Account ID', '0689a263-...09d9d'),
            _infoRow('Test Cases', '36 In-App'),
            _infoRow('Integration', 'Prebid Rendering'),
          ]),
          const SizedBox(height: 16),

          // Features
          _sectionTitle(context, 'Features'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _featureChip('Banner Ads'),
              _featureChip('Video Outstream'),
              _featureChip('Interstitial'),
              _featureChip('Rewarded'),
              _featureChip('Native Ads'),
              _featureChip('Multiformat'),
              _featureChip('MRAID 2.0/3.0'),
              _featureChip('GDPR/COPPA'),
              _featureChip('User Targeting'),
              _featureChip('Dark Mode'),
              _featureChip('Event Logging'),
              _featureChip('Load Timing'),
            ],
          ),
          const SizedBox(height: 24),

          // Links
          _sectionTitle(context, 'Links'),
          const SizedBox(height: 8),
          _linkTile(context, Icons.code, 'Source Code', _repoUrl),
          _linkTile(
            context,
            Icons.book,
            'Prebid Documentation',
            'https://docs.prebid.org/prebid-mobile/prebid-mobile.html',
          ),
          _linkTile(
            context,
            Icons.bug_report,
            'Report Issue',
            '$_repoUrl/issues',
          ),
          const SizedBox(height: 24),

          // Footer
          Center(
            child: Text(
              '© ${DateTime.now().year} Prebid.org',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _infoCard(BuildContext context, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor.withAlpha(60)),
      ),
      child: Column(children: rows),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _featureChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }

  Widget _linkTile(
    BuildContext context,
    IconData icon,
    String title,
    String url,
  ) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        url,
        style: const TextStyle(fontSize: 10),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.open_in_new, size: 14),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}
