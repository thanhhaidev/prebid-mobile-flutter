import 'package:flutter/material.dart';

import '../demo/demo_screen.dart' show DemoScaffold;
import '../services/iab_consent_store.dart';
import '../theme/app_theme.dart';
import '../widgets/section_header.dart';

enum _PrefType { boolean, string, integer }

class _Pref {
  const _Pref(this.key, this.title, this.type);
  final String key;
  final String title;
  final _PrefType type;
}

/// Utilities → "IAB Consent Settings" — the original `ConsentSettingsFragment`
/// (`user_consent_settings.xml`, spec §4.2). Writes the raw IAB keys into the
/// platform default store ([IabConsentStore]): switches as bool, integer
/// fields as int, text as String; an empty field (or `-1` for integers)
/// removes the key. Text fields show their current value as the summary.
class IabConsentSettingsPage extends StatefulWidget {
  const IabConsentSettingsPage({super.key});

  @override
  State<IabConsentSettingsPage> createState() => _IabConsentSettingsPageState();
}

class _IabConsentSettingsPageState extends State<IabConsentSettingsPage> {
  static const _sections = <(String, List<_Pref>)>[
    (
      'TCF v1',
      [
        _Pref(IabConsentStore.cmpPresent, 'CMPPresent', _PrefType.boolean),
        _Pref(
          IabConsentStore.subjectToGdprV1,
          'SubjectToGDPR',
          _PrefType.string,
        ),
        _Pref(
          IabConsentStore.consentStringV1,
          'ConsentString',
          _PrefType.string,
        ),
      ],
    ),
    (
      'TCF v2',
      [
        _Pref(IabConsentStore.cmpSdkId, 'CMP SDK ID', _PrefType.integer),
        _Pref(IabConsentStore.gdprApplies, 'SubjectToGDPR', _PrefType.integer),
        _Pref(IabConsentStore.tcString, 'ConsentString', _PrefType.string),
      ],
    ),
    (
      'CCPA',
      [
        _Pref(
          IabConsentStore.usPrivacyString,
          'US Privacy String',
          _PrefType.string,
        ),
      ],
    ),
    (
      'TESTING',
      [_Pref(IabConsentStore.keepSettings, 'KeepSettings', _PrefType.boolean)],
    ),
  ];

  final Map<String, Object?> _values = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    for (final (_, prefs) in _sections) {
      for (final p in prefs) {
        _values[p.key] = await IabConsentStore.get(p.key);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _setBool(_Pref p, bool v) async {
    setState(() => _values[p.key] = v);
    await IabConsentStore.setBool(p.key, v);
  }

  Future<void> _edit(_Pref p) async {
    final controller = TextEditingController(
      text: _values[p.key]?.toString() ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(p.title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: p.type == _PrefType.integer
              ? const TextInputType.numberWithOptions(signed: true)
              : TextInputType.text,
          style: AppFonts.monoStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;

    if (p.type == _PrefType.integer) {
      final n = int.tryParse(result);
      if (n == null || n == -1) {
        await IabConsentStore.remove(p.key);
      } else {
        await IabConsentStore.setInt(p.key, n);
      }
    } else if (result.isEmpty) {
      await IabConsentStore.remove(p.key);
    } else {
      await IabConsentStore.setString(p.key, result);
    }
    _values[p.key] = await IabConsentStore.get(p.key);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = DemoColors.of(context);
    return DemoScaffold(
      title: 'IAB Consent Settings',
      progressOverlay: false,
      child: ListView(
        children: [
          for (final (title, prefs) in _sections) ...[
            SectionHeader(title),
            for (final p in prefs)
              if (p.type == _PrefType.boolean)
                SwitchListTile(
                  title: Text(p.title),
                  subtitle: Text(
                    p.key,
                    style: AppFonts.monoStyle(fontSize: 11),
                  ),
                  value: _values[p.key] == true,
                  onChanged: (v) => _setBool(p, v),
                )
              else
                ListTile(
                  title: Text(p.title),
                  subtitle: Text(
                    _values[p.key]?.toString() ?? 'Not set',
                    style: AppFonts.monoStyle(
                      fontSize: 12,
                      color: _values[p.key] == null ? c.muted : c.codeFg,
                    ),
                  ),
                  trailing: Text(
                    p.key,
                    style: AppFonts.monoStyle(fontSize: 10, color: c.muted),
                  ),
                  onTap: () => _edit(p),
                ),
            Divider(color: c.border),
          ],
        ],
      ),
    );
  }
}
