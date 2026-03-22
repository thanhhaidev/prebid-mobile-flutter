import 'package:flutter/material.dart';
import 'package:prebid_mobile_flutter/prebid_mobile_flutter.dart';

/// User Targeting Data page — manage user/app keywords and ext data.
///
/// Mirrors Prebid iOS demo's targeting configuration functionality.
class TargetingDataPage extends StatefulWidget {
  const TargetingDataPage({super.key});

  @override
  State<TargetingDataPage> createState() => _TargetingDataPageState();
}

class _TargetingDataPageState extends State<TargetingDataPage> {
  // User Keywords
  final _userKeywordController = TextEditingController();
  List<String> _userKeywords = [];

  // App Keywords
  final _appKeywordController = TextEditingController();
  final List<String> _appKeywords = [];

  // App Ext Data
  final _extDataKeyController = TextEditingController();
  final _extDataValueController = TextEditingController();
  final List<MapEntry<String, String>> _extDataEntries = [];

  // Global ORTB Config
  final _ortbConfigController = TextEditingController();

  // App Info
  final _contentUrlController = TextEditingController();
  final _publisherNameController = TextEditingController();
  final _storeUrlController = TextEditingController();
  final _domainController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentValues();
  }

  Future<void> _loadCurrentValues() async {
    final userKw = await PrebidTargeting.getUserKeywords();
    final ortb = await PrebidTargeting.getGlobalOrtbConfig();
    setState(() {
      _userKeywords = userKw;
      if (ortb != null) _ortbConfigController.text = ortb;
    });
  }

  @override
  void dispose() {
    _userKeywordController.dispose();
    _appKeywordController.dispose();
    _extDataKeyController.dispose();
    _extDataValueController.dispose();
    _ortbConfigController.dispose();
    _contentUrlController.dispose();
    _publisherNameController.dispose();
    _storeUrlController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  // ---- User Keywords ----

  Future<void> _addUserKeyword() async {
    final kw = _userKeywordController.text.trim();
    if (kw.isEmpty) return;
    await PrebidTargeting.addUserKeyword(kw);
    _userKeywordController.clear();
    final updated = await PrebidTargeting.getUserKeywords();
    setState(() => _userKeywords = updated);
    _showSnack('Added user keyword: $kw');
  }

  Future<void> _removeUserKeyword(String kw) async {
    await PrebidTargeting.removeUserKeyword(kw);
    final updated = await PrebidTargeting.getUserKeywords();
    setState(() => _userKeywords = updated);
  }

  Future<void> _clearUserKeywords() async {
    await PrebidTargeting.clearUserKeywords();
    setState(() => _userKeywords.clear());
    _showSnack('Cleared all user keywords');
  }

  // ---- App Keywords ----

  Future<void> _addAppKeyword() async {
    final kw = _appKeywordController.text.trim();
    if (kw.isEmpty) return;
    await PrebidTargeting.addAppKeyword(kw);
    _appKeywordController.clear();
    setState(() => _appKeywords.add(kw));
    _showSnack('Added app keyword: $kw');
  }

  Future<void> _removeAppKeyword(String kw) async {
    await PrebidTargeting.removeAppKeyword(kw);
    setState(() => _appKeywords.remove(kw));
  }

  Future<void> _clearAppKeywords() async {
    await PrebidTargeting.clearAppKeywords();
    setState(() => _appKeywords.clear());
    _showSnack('Cleared all app keywords');
  }

  // ---- App Ext Data ----

  Future<void> _addExtData() async {
    final key = _extDataKeyController.text.trim();
    final value = _extDataValueController.text.trim();
    if (key.isEmpty || value.isEmpty) return;
    await PrebidTargeting.addAppExtData(key: key, value: value);
    _extDataKeyController.clear();
    _extDataValueController.clear();
    setState(() => _extDataEntries.add(MapEntry(key, value)));
    _showSnack('Added ext data: $key=$value');
  }

  Future<void> _clearExtData() async {
    await PrebidTargeting.clearAppExtData();
    setState(() => _extDataEntries.clear());
    _showSnack('Cleared all ext data');
  }

  // ---- App Info ----

  Future<void> _applyAppInfo() async {
    final contentUrl = _contentUrlController.text.trim();
    final publisherName = _publisherNameController.text.trim();
    final storeUrl = _storeUrlController.text.trim();
    final domain = _domainController.text.trim();

    if (contentUrl.isNotEmpty) {
      await PrebidTargeting.setContentUrl(contentUrl);
    }
    if (publisherName.isNotEmpty) {
      await PrebidTargeting.setPublisherName(publisherName);
    }
    if (storeUrl.isNotEmpty) {
      await PrebidTargeting.setStoreUrl(storeUrl);
    }
    if (domain.isNotEmpty) {
      await PrebidTargeting.setDomain(domain);
    }

    _showSnack('App info applied');
  }

  // ---- ORTB Config ----

  Future<void> _applyOrtbConfig() async {
    final config = _ortbConfigController.text.trim();
    await PrebidTargeting.setGlobalOrtbConfig(config.isEmpty ? null : config);
    _showSnack('Global ORTB config ${config.isEmpty ? "cleared" : "applied"}');
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontSize: 12)),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Targeting Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- User Keywords ----
          _sectionHeader('User Keywords', primary),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userKeywordController,
                  decoration: _inputDecoration('Add keyword'),
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: (_) => _addUserKeyword(),
                ),
              ),
              const SizedBox(width: 8),
              _iconButton(Icons.add_circle, _addUserKeyword),
            ],
          ),
          const SizedBox(height: 6),
          _chipWrap(_userKeywords, _removeUserKeyword, Colors.blue),
          if (_userKeywords.isNotEmpty)
            _clearButton('Clear All', _clearUserKeywords),
          const Divider(height: 24),

          // ---- App Keywords ----
          _sectionHeader('App Keywords', primary),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _appKeywordController,
                  decoration: _inputDecoration('Add keyword'),
                  style: const TextStyle(fontSize: 13),
                  onSubmitted: (_) => _addAppKeyword(),
                ),
              ),
              const SizedBox(width: 8),
              _iconButton(Icons.add_circle, _addAppKeyword),
            ],
          ),
          const SizedBox(height: 6),
          _chipWrap(_appKeywords, _removeAppKeyword, Colors.teal),
          if (_appKeywords.isNotEmpty)
            _clearButton('Clear All', _clearAppKeywords),
          const Divider(height: 24),

          // ---- App Ext Data ----
          _sectionHeader('App Ext Data', primary),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _extDataKeyController,
                  decoration: _inputDecoration('Key'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _extDataValueController,
                  decoration: _inputDecoration('Value'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              _iconButton(Icons.add_circle, _addExtData),
            ],
          ),
          const SizedBox(height: 6),
          if (_extDataEntries.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _extDataEntries
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          '${e.key} = ${e.value}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            _clearButton('Clear All', _clearExtData),
          ],
          const Divider(height: 24),

          // ---- App Info ----
          _sectionHeader('App Information', primary),
          const SizedBox(height: 6),
          _smallField('Content URL', _contentUrlController),
          const SizedBox(height: 6),
          _smallField('Publisher Name', _publisherNameController),
          const SizedBox(height: 6),
          _smallField('Store URL', _storeUrlController),
          const SizedBox(height: 6),
          _smallField('Domain', _domainController),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: _applyAppInfo,
              child: const Text('Apply', style: TextStyle(fontSize: 12)),
            ),
          ),
          const Divider(height: 24),

          // ---- Global ORTB Config ----
          _sectionHeader('Global ORTB Config', primary),
          const SizedBox(height: 6),
          TextField(
            controller: _ortbConfigController,
            decoration: _inputDecoration('JSON config'),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            maxLines: 4,
            minLines: 2,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: _applyOrtbConfig,
              child: const Text(
                'Apply ORTB Config',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---- Helpers ----

  Widget _sectionHeader(String title, Color color) => Text(
    title,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: 0.5,
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
  );

  Widget _smallField(String label, TextEditingController ctrl) => TextField(
    controller: ctrl,
    decoration: _inputDecoration(label),
    style: const TextStyle(fontSize: 13),
  );

  Widget _iconButton(IconData icon, VoidCallback onPressed) => IconButton(
    icon: Icon(icon, size: 24),
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
  );

  Widget _chipWrap(
    List<String> items,
    Future<void> Function(String) onDelete,
    MaterialColor color,
  ) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No items',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade400,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: items
          .map(
            (kw) => Chip(
              label: Text(kw, style: const TextStyle(fontSize: 11)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => onDelete(kw),
              backgroundColor: color.shade50,
              side: BorderSide(color: color.shade200),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
          .toList(),
    );
  }

  Widget _clearButton(String label, VoidCallback onPressed) => Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.clear_all, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
    ),
  );
}
