import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../data/test_case_registry.dart';
import '../models/demo_ad_category.dart';
import '../models/demo_ad_format.dart';
import '../models/demo_integration.dart';
import '../models/test_case.dart';
import '../utils/app_settings.dart';
import '../utils/category_style.dart';
import 'detail/banner_detail_page.dart';
import 'detail/interstitial_detail_page.dart';
import 'detail/multiformat_detail_page.dart';
import 'detail/native_detail_page.dart';
import 'detail/original_banner_detail_page.dart';
import 'detail/rewarded_detail_page.dart';
import 'detail/video_detail_page.dart';
import 'settings_page.dart';

/// Main examples list — mirrors the Prebid reference test app: a search field,
/// an integration-type filter row (In-App / GAM / Original), an ad-format
/// filter row, quick privacy/debug switches, and a flat list of test cases.
class ExamplesPage extends StatefulWidget {
  const ExamplesPage({super.key});

  @override
  State<ExamplesPage> createState() => _ExamplesPageState();
}

class _ExamplesPageState extends State<ExamplesPage> {
  /// Selected integration, or null for "All".
  DemoIntegration? _integration;

  /// Selected ad-format category ([DemoAdCategory.all] = no filter).
  DemoAdCategory _category = DemoAdCategory.all;

  String _searchText = '';
  bool _gdpr = AppSettings.gdpr;
  bool _pbsDebug = AppSettings.pbsDebug;

  List<TestCase> get _filtered {
    final q = _searchText.toLowerCase();
    return TestCaseRegistry.allCases.where((t) {
      final matchesIntegration =
          _integration == null || t.integration == _integration;
      final matchesCategory =
          _category == DemoAdCategory.all || categoryOf(t) == _category;
      final matchesSearch =
          q.isEmpty ||
          t.title.toLowerCase().contains(q) ||
          t.configId.toLowerCase().contains(q);
      return matchesIntegration && matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prebid Flutter Demo'),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search examples',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchText = v),
            ),
          ),

          // Integration-type filter row
          _chipRow(
            children: [
              _integrationChip(null, 'All'),
              for (final i in DemoIntegration.values)
                _integrationChip(i, i.label),
            ],
          ),
          const SizedBox(height: 8),

          // Ad-format filter row
          _chipRow(
            children: [
              for (final c in DemoAdCategory.values) _categoryChip(c),
            ],
          ),
          const SizedBox(height: 8),

          // Quick toggles + settings gear
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _switchTile(
                  label: 'Enable GDPR',
                  value: _gdpr,
                  onChanged: (v) async {
                    setState(() => _gdpr = v);
                    await AppSettings.setGdpr(v);
                    await PrebidTargeting.setSubjectToGDPR(v);
                  },
                ),
                const SizedBox(width: 16),
                _switchTile(
                  label: 'PBS Debug',
                  value: _pbsDebug,
                  onChanged: (v) async {
                    setState(() => _pbsDebug = v);
                    await AppSettings.setPbsDebug(v);
                    await PrebidMobile.setPbsDebug(v);
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.settings_rounded),
                  tooltip: 'App Settings',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No examples found',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 64),
                    itemBuilder: (context, i) => _caseRow(filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  /// Horizontal, scrollable row of filter chips.
  Widget _chipRow({required List<Widget> children}) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }

  Widget _integrationChip(DemoIntegration? value, String label) {
    final selected = _integration == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _integration = value),
    );
  }

  Widget _categoryChip(DemoAdCategory c) {
    final selected = _category == c;
    return FilterChip(
      label: Text(c.label),
      selected: selected,
      showCheckmark: false,
      avatar: Icon(
        styleFor(c).icon,
        size: 18,
        color: selected
            ? styleFor(c).color
            : Theme.of(context).colorScheme.outline,
      ),
      onSelected: (_) => setState(() => _category = c),
    );
  }

  Widget _switchTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _caseRow(TestCase tc) {
    final theme = Theme.of(context);
    final category = categoryOf(tc);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CategoryAvatar(category: category),
      title: Text(
        tc.title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          tc.configId,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: theme.colorScheme.outline,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.outline,
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _detailPage(tc)),
      ),
    );
  }

  Widget _detailPage(TestCase tc) {
    // Original API renders through google_mobile_ads (keyword handoff).
    if (tc.integration == DemoIntegration.original) {
      return OriginalBannerDetailPage(tc: tc);
    }
    // Banner and interstitial detail pages are integration-aware (In-App / GAM
    // / AdMob / MAX); rewarded / native / instream / multiformat are In-App.
    return switch (tc.format) {
      DemoAdFormat.displayBanner ||
      DemoAdFormat.videoBanner => BannerDetailPage(tc: tc),
      DemoAdFormat.displayInterstitial ||
      DemoAdFormat.videoInterstitial => InterstitialDetailPage(tc: tc),
      DemoAdFormat.displayRewarded ||
      DemoAdFormat.videoRewarded => RewardedDetailPage(tc: tc),
      DemoAdFormat.native => NativeDetailPage(tc: tc),
      DemoAdFormat.videoInstream => VideoDetailPage(tc: tc),
      DemoAdFormat.multiformat => MultiformatDetailPage(tc: tc),
    };
  }
}
