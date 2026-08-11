import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../utils/app_settings.dart';

/// IAB Consent settings — GDPR (TCF) and CCPA (US Privacy).
///
/// Mirrors the reference app's "IAB Consent Settings" utility.
class ConsentSettingsPage extends StatefulWidget {
  const ConsentSettingsPage({super.key});

  @override
  State<ConsentSettingsPage> createState() => _ConsentSettingsPageState();
}

class _ConsentSettingsPageState extends State<ConsentSettingsPage> {
  bool _gdpr = AppSettings.gdpr;
  final _consentController = TextEditingController(text: AppSettings.gdprConsent);
  final _uspController = TextEditingController();

  @override
  void initState() {
    super.initState();
    PrebidTargeting.getUSPrivacyString().then((v) {
      if (v != null && mounted) _uspController.text = v;
    });
  }

  @override
  void dispose() {
    _consentController.dispose();
    _uspController.dispose();
    super.dispose();
  }

  Future<void> _setGdpr(bool v) async {
    setState(() => _gdpr = v);
    await AppSettings.setGdpr(v);
    await PrebidTargeting.setSubjectToGDPR(v);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 900)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IAB Consent Settings')),
      body: ListView(
        children: [
          _sectionHeader('TCF v2 (GDPR)'),
          SwitchListTile(
            title: const Text('SubjectToGDPR'),
            value: _gdpr,
            onChanged: _setGdpr,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _consentController,
              decoration: const InputDecoration(
                labelText: 'ConsentString',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onSubmitted: (v) async {
                await AppSettings.setGdprConsent(v);
                await PrebidTargeting.setGDPRConsentString(v);
                _snack('GDPR consent string saved');
              },
            ),
          ),
          const Divider(),
          _sectionHeader('CCPA'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _uspController,
              decoration: const InputDecoration(
                labelText: 'US Privacy String (e.g. 1YNN)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) async {
                await PrebidTargeting.setUSPrivacyString(v.isEmpty ? null : v);
                _snack('US Privacy string saved');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(
      title,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    ),
  );
}
