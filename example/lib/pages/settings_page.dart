import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../main.dart';
import '../utils/app_settings.dart';
import 'targeting_data_page.dart';

/// Settings page — mirrors Prebid demo's SettingsViewController.
///
/// All settings are persisted via SharedPreferences.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _serverUrlCtrl;
  late final TextEditingController _accountIdCtrl;
  late final TextEditingController _gdprConsentCtrl;
  bool _pbsDebug = true;
  bool _shareGeo = false;
  bool _coppa = false;
  bool _gdpr = false;
  bool _darkMode = false;
  int _logLevelIndex = 3;

  static const _logLevels = ['verbose', 'warn', 'error', 'debug'];

  @override
  void initState() {
    super.initState();
    _serverUrlCtrl = TextEditingController(text: AppSettings.serverUrl);
    _accountIdCtrl = TextEditingController(text: AppSettings.accountId);
    _gdprConsentCtrl = TextEditingController(text: AppSettings.gdprConsent);
    _pbsDebug = AppSettings.pbsDebug;
    _shareGeo = AppSettings.shareGeo;
    _coppa = AppSettings.coppa;
    _gdpr = AppSettings.gdpr;
    _logLevelIndex = AppSettings.logLevelIndex;
    _darkMode = AppSettings.darkMode;
  }

  @override
  void dispose() {
    _serverUrlCtrl.dispose();
    _accountIdCtrl.dispose();
    _gdprConsentCtrl.dispose();
    super.dispose();
  }

  Future<void> _applySettings() async {
    // Save to SharedPreferences
    await AppSettings.setServerUrl(_serverUrlCtrl.text.trim());
    await AppSettings.setAccountId(_accountIdCtrl.text.trim());
    await AppSettings.setPbsDebug(_pbsDebug);
    await AppSettings.setShareGeo(_shareGeo);
    await AppSettings.setCoppa(_coppa);
    await AppSettings.setGdpr(_gdpr);
    await AppSettings.setGdprConsent(_gdprConsentCtrl.text.trim());
    await AppSettings.setLogLevel(_logLevelIndex);

    // Apply to SDK
    await PrebidMobile.setPbsDebug(_pbsDebug);
    await PrebidMobile.setLogLevel(PrebidLogLevel.values[_logLevelIndex]);
    await PrebidMobile.setShareGeoLocation(_shareGeo);
    await PrebidTargeting.setSubjectToCOPPA(_coppa);
    if (_gdpr) {
      await PrebidTargeting.setSubjectToGDPR(true);
      final consent = _gdprConsentCtrl.text.trim();
      if (consent.isNotEmpty) {
        await PrebidTargeting.setGDPRConsentString(consent);
      }
    } else {
      await PrebidTargeting.setSubjectToGDPR(false);
    }

    await PrebidMobile.initializeSdk(
      prebidServerUrl: _serverUrlCtrl.text.trim(),
      accountId: _accountIdCtrl.text.trim(),
      completion: (status, error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(switch (status) {
                InitializationStatus.succeeded => '✅ SDK re-initialized',
                InitializationStatus.serverStatusWarning =>
                  '⚠️ SDK ready (warning)',
                InitializationStatus.failed =>
                  '❌ Failed: ${error ?? "unknown"}',
              }),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  Future<void> _resetDefaults() async {
    await AppSettings.resetDefaults();
    setState(() {
      _serverUrlCtrl.text = AppSettings.defaultServerUrl;
      _accountIdCtrl.text = AppSettings.defaultAccountId;
      _pbsDebug = true;
      _shareGeo = false;
      _coppa = false;
      _gdpr = false;
      _gdprConsentCtrl.text = '';
      _logLevelIndex = 3;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings reset to defaults'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset Defaults',
            onPressed: _resetDefaults,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // — Appearance
          _sectionHeader('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode', style: TextStyle(fontSize: 14)),
            secondary: Icon(
              _darkMode ? Icons.dark_mode : Icons.light_mode,
              size: 20,
            ),
            value: _darkMode,
            dense: true,
            onChanged: (v) {
              setState(() => _darkMode = v);
              AppSettings.setDarkMode(v);
              // Update app theme
              PrebidDemoApp.darkModeNotifier.value = v;
            },
          ),
          const Divider(height: 24),

          // — PBS Server Configuration
          _sectionHeader('PBS Server Configuration'),
          const SizedBox(height: 8),
          TextField(
            controller: _serverUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'PBS Server URL',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountIdCtrl,
            decoration: const InputDecoration(
              labelText: 'Account ID',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),

          // — SDK Config
          _sectionHeader('SDK Configuration'),
          SwitchListTile(
            title: const Text('PBS Debug', style: TextStyle(fontSize: 14)),
            value: _pbsDebug,
            dense: true,
            onChanged: (v) => setState(() => _pbsDebug = v),
          ),
          SwitchListTile(
            title: const Text(
              'Share Geo Location',
              style: TextStyle(fontSize: 14),
            ),
            value: _shareGeo,
            dense: true,
            onChanged: (v) => setState(() => _shareGeo = v),
          ),
          ListTile(
            title: const Text('Log Level', style: TextStyle(fontSize: 14)),
            dense: true,
            trailing: DropdownButton<int>(
              value: _logLevelIndex,
              items: List.generate(
                _logLevels.length,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(
                    _logLevels[i],
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              onChanged: (v) {
                if (v != null) setState(() => _logLevelIndex = v);
              },
            ),
          ),
          const Divider(height: 24),

          // — Privacy
          _sectionHeader('Privacy'),
          SwitchListTile(
            title: const Text('COPPA', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              'Children\'s Online Privacy Protection',
              style: TextStyle(fontSize: 11),
            ),
            value: _coppa,
            dense: true,
            onChanged: (v) => setState(() => _coppa = v),
          ),
          SwitchListTile(
            title: const Text('GDPR', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              'General Data Protection Regulation',
              style: TextStyle(fontSize: 11),
            ),
            value: _gdpr,
            dense: true,
            onChanged: (v) => setState(() => _gdpr = v),
          ),
          if (_gdpr)
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 4,
              ),
              child: TextField(
                controller: _gdprConsentCtrl,
                decoration: const InputDecoration(
                  labelText: 'GDPR Consent String',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          const Divider(height: 24),

          // — Targeting Data
          _sectionHeader('Targeting Data'),
          const SizedBox(height: 4),
          ListTile(
            leading: const Icon(Icons.tune, size: 20),
            title: const Text(
              'User & App Targeting',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: const Text(
              'Keywords, ext data, ORTB config',
              style: TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            dense: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TargetingDataPage()),
            ),
          ),
          const SizedBox(height: 32),

          // — Apply button
          FilledButton.icon(
            onPressed: _applySettings,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Apply & Re-initialize SDK'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 2),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.5,
      ),
    ),
  );
}
