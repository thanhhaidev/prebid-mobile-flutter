import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../main.dart';
import '../utils/app_settings.dart';
import '../utils/bid_inspector.dart';
import 'bid_inspector_page.dart';
import 'targeting_data_page.dart';

/// SDK settings — mirrors the settings screens of Prebid's internal test app.
///
/// Values persist via SharedPreferences and are applied to the SDK at startup
/// ([AppSettings.applyToSdk]); "Apply" pushes them and re-initializes the SDK.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _serverUrl = TextEditingController(text: AppSettings.serverUrl);
  final _accountId = TextEditingController(text: AppSettings.accountId);
  final _gdprConsent = TextEditingController(text: AppSettings.gdprConsent);
  final _timeout = TextEditingController(text: _num(AppSettings.timeoutMillis));
  final _creativeTimeout = TextEditingController(
    text: _num(AppSettings.creativeFactoryTimeout),
  );
  final _creativeTimeoutPre = TextEditingController(
    text: _num(AppSettings.creativeFactoryTimeoutPreRender),
  );
  final _auctionSettingsId = TextEditingController(
    text: AppSettings.auctionSettingsId,
  );

  bool _pbsDebug = AppSettings.pbsDebug;
  bool _shareGeo = AppSettings.shareGeo;
  bool _coppa = AppSettings.coppa;
  bool _gdpr = AppSettings.gdpr;
  bool _darkMode = AppSettings.darkMode;
  PrebidLogLevel _logLevel = AppSettings.logLevel;
  bool _filterUncached = AppSettings.filterOutUncachedBids;
  PrebidEidsPlacement _eidsPlacement = AppSettings.eidsPlacement;
  bool _includeWinners = AppSettings.includeWinners;
  bool _includeBidderKeys = AppSettings.includeBidderKeys;
  bool _sendSharedId = AppSettings.sendSharedId;
  ExternalUserId? _sharedId;
  String _sdkVersion = '';

  static String _num(int v) => v > 0 ? '$v' : '';

  @override
  void initState() {
    super.initState();
    _refreshSharedId();
    PrebidMobile.getSdkVersion().then((v) {
      if (mounted) setState(() => _sdkVersion = v);
    });
  }

  Future<void> _refreshSharedId() async {
    final id = await PrebidMobile.getSharedId();
    if (mounted) setState(() => _sharedId = id);
  }

  @override
  void dispose() {
    for (final c in [
      _serverUrl,
      _accountId,
      _gdprConsent,
      _timeout,
      _creativeTimeout,
      _creativeTimeoutPre,
      _auctionSettingsId,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _apply() async {
    await AppSettings.setServerUrl(_serverUrl.text.trim());
    await AppSettings.setAccountId(_accountId.text.trim());
    await AppSettings.setPbsDebug(_pbsDebug);
    await AppSettings.setShareGeo(_shareGeo);
    await AppSettings.setCoppa(_coppa);
    await AppSettings.setGdpr(_gdpr);
    await AppSettings.setGdprConsent(_gdprConsent.text.trim());
    await AppSettings.setLogLevel(_logLevel);
    await AppSettings.setTimeoutMillis(int.tryParse(_timeout.text) ?? 0);
    await AppSettings.setCreativeFactoryTimeout(
      int.tryParse(_creativeTimeout.text) ?? 0,
    );
    await AppSettings.setCreativeFactoryTimeoutPreRender(
      int.tryParse(_creativeTimeoutPre.text) ?? 0,
    );
    await AppSettings.setFilterOutUncachedBids(_filterUncached);
    await AppSettings.setEidsPlacement(_eidsPlacement);
    await AppSettings.setIncludeWinners(_includeWinners);
    await AppSettings.setIncludeBidderKeys(_includeBidderKeys);
    await AppSettings.setSendSharedId(_sendSharedId);
    await AppSettings.setAuctionSettingsId(_auctionSettingsId.text.trim());

    await AppSettings.applyToSdk();
    await PrebidMobile.initializeSdk(
      prebidServerUrl: AppSettings.serverUrl,
      accountId: AppSettings.accountId,
      completion: (status, error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(switch (status) {
              InitializationStatus.succeeded => '✅ SDK re-initialized',
              InitializationStatus.serverStatusWarning =>
                '⚠️ SDK ready (warning)',
              InitializationStatus.failed => '❌ Failed: ${error ?? "unknown"}',
            }),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  Future<void> _resetDefaults() async {
    await AppSettings.resetDefaults();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
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
          _section('Appearance'),
          _switch('Dark Mode', _darkMode, (v) {
            setState(() => _darkMode = v);
            AppSettings.setDarkMode(v);
            PrebidDemoApp.darkModeNotifier.value = v;
          }),

          _section('Prebid Server'),
          _text('PBS Server URL', _serverUrl),
          _text('Account ID', _accountId),
          _text('Bid timeout (ms)', _timeout, number: true, hint: 'default'),
          _text(
            'Auction settings ID',
            _auctionSettingsId,
            hint: 'stored request id (optional)',
          ),

          _section('SDK'),
          if (_sdkVersion.isNotEmpty)
            ListTile(
              dense: true,
              title: const Text('Prebid SDK version'),
              trailing: Text(_sdkVersion),
            ),
          _switch('PBS Debug', _pbsDebug, (v) => setState(() => _pbsDebug = v)),
          _switch(
            'Share Geo Location',
            _shareGeo,
            (v) => setState(() => _shareGeo = v),
          ),
          ListTile(
            dense: true,
            title: const Text('Log Level'),
            trailing: DropdownButton<PrebidLogLevel>(
              value: _logLevel,
              items: [
                for (final l in PrebidLogLevel.values)
                  DropdownMenuItem(value: l, child: Text(l.name)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _logLevel = v);
              },
            ),
          ),
          _text(
            'Creative factory timeout (ms)',
            _creativeTimeout,
            number: true,
            hint: 'default',
          ),
          _text(
            'Pre-render timeout (ms)',
            _creativeTimeoutPre,
            number: true,
            hint: 'default',
          ),

          _section('Bidding'),
          _switch(
            'Filter out uncached bids',
            _filterUncached,
            (v) => setState(() => _filterUncached = v),
            subtitle: 'Promote the next cached bid when Prebid Cache fails',
          ),
          ListTile(
            dense: true,
            title: const Text('EIDs placement'),
            subtitle: const Text('user.eids / user.ext.eids'),
            trailing: DropdownButton<PrebidEidsPlacement>(
              value: _eidsPlacement,
              items: [
                for (final p in PrebidEidsPlacement.values)
                  DropdownMenuItem(value: p, child: Text(p.name)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _eidsPlacement = v);
              },
            ),
          ),
          _switch(
            'Include winners',
            _includeWinners,
            (v) => setState(() => _includeWinners = v),
            subtitle: 'ext.prebid.targeting.includewinners',
          ),
          _switch(
            'Include bidder keys',
            _includeBidderKeys,
            (v) => setState(() => _includeBidderKeys = v),
            subtitle: 'ext.prebid.targeting.includebidderkeys',
          ),

          _section('Identity'),
          _switch(
            'Send SharedID',
            _sendSharedId,
            (v) => setState(() => _sendSharedId = v),
            subtitle: 'Prebid first-party id (pubcid.org) in user.eids',
          ),
          ListTile(
            dense: true,
            title: const Text('SharedID'),
            subtitle: SelectableText(
              _sharedId?.identifier ?? '…',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: _sharedId == null
                      ? null
                      : () => Clipboard.setData(
                          ClipboardData(text: _sharedId!.identifier),
                        ),
                ),
                IconButton(
                  tooltip: 'Reset SharedID',
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: () async {
                    await PrebidMobile.resetSharedId();
                    await _refreshSharedId();
                  },
                ),
              ],
            ),
          ),

          _section('Privacy'),
          _switch(
            'COPPA',
            _coppa,
            (v) => setState(() => _coppa = v),
            subtitle: 'Children\'s Online Privacy Protection',
          ),
          _switch(
            'GDPR',
            _gdpr,
            (v) => setState(() => _gdpr = v),
            subtitle: 'General Data Protection Regulation',
          ),
          if (_gdpr) _text('GDPR Consent String', _gdprConsent),

          _section('Tools'),
          ListenableBuilder(
            listenable: BidInspector.instance,
            builder: (context, _) => ListTile(
              dense: true,
              leading: const Icon(Icons.manage_search_rounded, size: 20),
              title: const Text('Bid Inspector'),
              subtitle: Text(
                BidInspector.instance.enabled
                    ? 'Capturing (${BidInspector.instance.records.length})'
                    : 'Off',
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BidInspectorPage()),
              ),
            ),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.tune, size: 20),
            title: const Text('User & App Targeting'),
            subtitle: const Text('Keywords, ext data, ORTB, OMID, location'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TargetingDataPage()),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _apply,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Apply & Re-initialize SDK'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 4),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1,
      ),
    ),
  );

  Widget _switch(
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    String? subtitle,
  }) => SwitchListTile(
    dense: true,
    title: Text(title),
    subtitle: subtitle == null
        ? null
        : Text(subtitle, style: const TextStyle(fontSize: 11)),
    value: value,
    onChanged: onChanged,
  );

  Widget _text(
    String label,
    TextEditingController controller, {
    bool number = false,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      style: const TextStyle(fontSize: 13),
    ),
  );
}
