import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../data/demo_item.dart';
import '../data/demo_items.dart';
import '../demo/demo_router.dart';
import '../demo/demo_screen.dart' show ConfigurationMode;
import '../services/iab_consent_store.dart';
import '../theme/app_theme.dart';
import '../widgets/plain_list_row.dart';
import '../widgets/segmented_row.dart';

/// App title of the Examples screen ("Prebid Rendering Kotlin Demo" in the
/// original).
const kAppTitle = 'Prebid Rendering Flutter Demo';

/// The Examples tab — the original `HeaderBiddingFragment` (spec §1.1):
/// search (label only), integration row, category row, the
/// "Enable GDPR" / "Enable Caching" switches and the configuration toggle,
/// then the plain list of demo items.
class ExamplesPage extends StatefulWidget {
  const ExamplesPage({super.key});

  @override
  State<ExamplesPage> createState() => _ExamplesPageState();
}

class _ExamplesPageState extends State<ExamplesPage> {
  final _search = TextEditingController();

  /// `null` = All (last segment, default).
  DemoIntegration? _integration;
  DemoCategory? _category;

  bool _gdpr = true;
  bool _caching = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    IabConsentStore.isGdprEnabled().then((v) {
      if (mounted) setState(() => _gdpr = v);
    });
    PrebidMobile.getUseCacheForReportingWithRenderingApi().then((v) {
      if (mounted) setState(() => _caching = v);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Remote AND integration AND category AND label contains the query.
  List<DemoItem> get _filtered {
    final q = _search.text.toLowerCase();
    return [
      for (final item in demoItems)
        if (item.remote &&
            (_integration == null || item.integration == _integration) &&
            (_category == null || item.category == _category) &&
            item.label.toLowerCase().contains(q))
          item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = DemoColors.of(context);
    final items = _filtered;
    return Scaffold(
      appBar: AppBar(title: const Text(kAppTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: c.muted),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close, color: c.muted),
                            onPressed: _search.clear,
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedRow<DemoIntegration?>(
                  values: const [...DemoIntegration.values, null],
                  selected: _integration,
                  labelOf: (v) => v?.label ?? 'All',
                  onChanged: (v) => setState(() => _integration = v),
                ),
                const SizedBox(height: 8),
                SegmentedRow<DemoCategory?>(
                  values: const [...DemoCategory.values, null],
                  selected: _category,
                  labelOf: (v) => v?.label ?? 'All',
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 4),
                _togglesRow(c),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) => PlainListRow(
                label: items[i].label,
                onTap: () => openDemo(context, items[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _togglesRow(DemoColors c) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  _switch('Enable GDPR', _gdpr, (v) {
                    setState(() => _gdpr = v);
                    IabConsentStore.setGdprEnabled(v);
                  }),
                  const SizedBox(width: 8),
                  _switch('Enable Caching', _caching, (v) {
                    setState(() => _caching = v);
                    PrebidMobile.setUseCacheForReportingWithRenderingApi(v);
                  }),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<bool>(
          valueListenable: ConfigurationMode.enabled,
          builder: (context, on, _) => Tooltip(
            message: 'Configuration mode',
            child: Material(
              color: on ? c.mint : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                side: BorderSide(color: on ? c.primary : c.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                onTap: () => ConfigurationMode.enabled.value = !on,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.tune,
                    size: 20,
                    color: on ? c.primaryStrong : c.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Transform.scale(
          scale: 0.8,
          child: Switch(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}
