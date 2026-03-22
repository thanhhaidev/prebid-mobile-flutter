import 'package:flutter/material.dart';

import '../data/test_case_registry.dart';
import '../models/demo_ad_format.dart';
import '../models/test_case.dart';
import 'detail/banner_detail_page.dart';
import 'detail/interstitial_detail_page.dart';
import 'detail/rewarded_detail_page.dart';
import 'detail/native_detail_page.dart';
import 'detail/video_detail_page.dart';
import 'detail/multiformat_detail_page.dart';
import 'about_page.dart';
import 'settings_page.dart';

/// Main examples list page — mirrors Prebid's ExamplesViewController.
///
/// Features:
/// - AdFormat filter chips
/// - Search bar for filtering by title
/// - Test case list with format badges and tap-to-navigate
class ExamplesPage extends StatefulWidget {
  const ExamplesPage({super.key});

  @override
  State<ExamplesPage> createState() => _ExamplesPageState();
}

class _ExamplesPageState extends State<ExamplesPage> {
  DemoAdFormat? _selectedFormat;
  String _searchText = '';

  List<TestCase> get _filtered {
    return TestCaseRegistry.allCases
        .where(
          (t) =>
              (_selectedFormat == null || t.format == _selectedFormat) &&
              (_searchText.isEmpty ||
                  t.title.toLowerCase().contains(_searchText.toLowerCase())),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prebid Flutter Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Ad format picker
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _formatChip('All', null),
                  ...DemoAdFormat.values.map((f) => _formatChip(f.label, f)),
                ],
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search test cases...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (v) => setState(() => _searchText = v),
            ),
          ),
          const SizedBox(height: 4),

          // Result count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                Text(
                  '${_filtered.length} test case${_filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const Spacer(),
                if (_selectedFormat != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedFormat = null),
                    child: Text(
                      'Clear filter',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Test case list
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No test cases found',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (context, i) {
                      final tc = _filtered[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        title: Text(
                          tc.title,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Row(
                          children: [
                            _formatBadge(tc.format),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                tc.configId,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => _detailPage(tc)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _formatChip(String label, DemoAdFormat? format) {
    final selected = _selectedFormat == format;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: selected,
        selectedColor: const Color(0xFF0068B5),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) => setState(() => _selectedFormat = format),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// Format badge with icon and color for the ad type.
  Widget _formatBadge(DemoAdFormat format) {
    final (icon, color) = switch (format) {
      DemoAdFormat.displayBanner => ('🖼', Colors.blue),
      DemoAdFormat.videoBanner => ('🎬', Colors.purple),
      DemoAdFormat.nativeBanner => ('📄', Colors.teal),
      DemoAdFormat.displayInterstitial => ('📱', Colors.indigo),
      DemoAdFormat.videoInterstitial => ('🎥', Colors.deepPurple),
      DemoAdFormat.displayRewarded => ('🏆', Colors.amber),
      DemoAdFormat.videoRewarded => ('🎯', Colors.orange),
      DemoAdFormat.videoInstream => ('📺', Colors.red),
      DemoAdFormat.native => ('🧩', Colors.green),
      DemoAdFormat.multiformat => ('✨', Colors.pink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.shade200, width: 0.5),
      ),
      child: Text(
        '$icon ${format.label}',
        style: TextStyle(fontSize: 9, color: color.shade700),
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
      DemoAdFormat.native ||
      DemoAdFormat.nativeBanner => NativeDetailPage(tc: tc),
      DemoAdFormat.videoInstream => VideoDetailPage(tc: tc),
      DemoAdFormat.multiformat => MultiformatDetailPage(tc: tc),
    };
  }
}
