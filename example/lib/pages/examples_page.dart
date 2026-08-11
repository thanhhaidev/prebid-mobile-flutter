import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../data/test_case_registry.dart';
import '../models/demo_ad_category.dart';
import '../models/demo_ad_format.dart';
import '../models/test_case.dart';
import '../utils/app_settings.dart';
import '../utils/category_style.dart';
import 'detail/banner_detail_page.dart';
import 'detail/interstitial_detail_page.dart';
import 'detail/multiformat_detail_page.dart';
import 'detail/native_detail_page.dart';
import 'detail/rewarded_detail_page.dart';
import 'detail/video_detail_page.dart';
import 'settings_page.dart';

/// Main examples list — search, ad-type filter chips, quick privacy/debug
/// toggles, and a card list of test cases.
class ExamplesPage extends StatefulWidget {
  const ExamplesPage({super.key});

  @override
  State<ExamplesPage> createState() => _ExamplesPageState();
}

class _ExamplesPageState extends State<ExamplesPage> {
  DemoAdCategory _category = DemoAdCategory.all;
  String _searchText = '';
  bool _gdpr = AppSettings.gdpr;
  bool _pbsDebug = AppSettings.pbsDebug;

  List<TestCase> get _filtered {
    final q = _searchText.toLowerCase();
    return TestCaseRegistry.allCases.where((t) {
      final matchesCategory =
          _category == DemoAdCategory.all || categoryOf(t) == _category;
      final matchesSearch =
          q.isEmpty ||
          t.title.toLowerCase().contains(q) ||
          t.configId.toLowerCase().contains(q);
      return matchesCategory && matchesSearch;
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

          // Category filter chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: DemoAdCategory.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _categoryChip(DemoAdCategory.values[i]),
            ),
          ),
          const SizedBox(height: 8),

          // Quick toggles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('GDPR'),
                  selected: _gdpr,
                  onSelected: (v) async {
                    setState(() => _gdpr = v);
                    await AppSettings.setGdpr(v);
                    await PrebidTargeting.setSubjectToGDPR(v);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('PBS Debug'),
                  selected: _pbsDebug,
                  onSelected: (v) async {
                    setState(() => _pbsDebug = v);
                    await AppSettings.setPbsDebug(v);
                    await PrebidMobile.setPbsDebug(v);
                  },
                ),
                const Spacer(),
                IconButton.filledTonal(
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'App Settings',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} example${filtered.length == 1 ? '' : 's'}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No examples found',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _caseCard(filtered[i]),
                  ),
          ),
        ],
      ),
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

  Widget _caseCard(TestCase tc) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CategoryAvatar(category: categoryOf(tc)),
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
      ),
    );
  }

  Widget _detailPage(TestCase tc) {
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
