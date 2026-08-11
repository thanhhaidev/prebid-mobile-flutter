import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../widgets/action_button.dart';
import '../widgets/result_panel.dart';

/// Demonstrates the **Original API** integration (Prebid issue #1270's "hand
/// keywords to the ad server" model): Prebid runs the auction and returns
/// targeting keywords, then the `google_mobile_ads` (Google Ad Manager) SDK
/// renders the ad — the Prebid SDK does not render it.
///
/// Flow:
///   1. [PrebidBannerAdUnit.fetchDemand] runs the auction → `targetingKeywords`.
///   2. Those keywords become `AdManagerAdRequest(customTargeting: ...)`.
///   3. `AdManagerBannerAd` loads and renders through GAM.
///
/// Note: this demo uses Google's public sample Ad Manager unit
/// (`/6499/example/banner`), which has no Prebid line items configured, so GAM
/// serves a Google sample creative and ignores the keywords. In production you
/// point `adUnitId` at your own GAM unit whose line items target the `hb_*`
/// keys, so a winning Prebid bid renders via the Prebid Universal Creative.
class OriginalApiPage extends StatefulWidget {
  const OriginalApiPage({super.key});

  @override
  State<OriginalApiPage> createState() => _OriginalApiPageState();
}

class _OriginalApiPageState extends State<OriginalApiPage> {
  /// Prebid Server stored impression config. Its requested size (300x250) must
  /// match one of the GAM [gma.AdSize]s requested below.
  static const _configId = 'prebid-demo-banner-300-250';
  static const _adSize = Size(300, 250);

  /// Google's public sample Ad Manager banner unit. Replace with your own.
  static const _gamAdUnitId = '/6499/example/banner';

  PrebidBannerAdUnit? _adUnit;
  gma.AdManagerBannerAd? _bannerAd;

  bool _loading = false;
  bool _bannerLoaded = false;
  String _result =
      'Idle. Tap "Fetch & Load" to run the auction and hand the\n'
      'targeting keywords to Google Ad Manager.';

  @override
  void dispose() {
    _bannerAd?.dispose();
    _adUnit?.destroy();
    super.dispose();
  }

  Future<void> _fetchAndLoad() async {
    setState(() {
      _loading = true;
      _bannerLoaded = false;
      _result = 'Running Prebid auction…';
    });

    // Tear down any previous ad objects before starting a new cycle.
    _bannerAd?.dispose();
    _bannerAd = null;
    await _adUnit?.destroy();

    // 1. Run the Prebid auction for a 300x250 banner (Original API).
    final adUnit = PrebidBannerAdUnit(
      configId: _configId,
      sizes: const [_adSize],
    );
    _adUnit = adUnit;

    final PrebidBidResponse response;
    try {
      response = await adUnit.fetchDemand();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = 'fetchDemand failed: $e';
      });
      return;
    }

    final keywords = response.targetingKeywords ?? const {};
    final kwText = keywords.isEmpty
        ? '(none — no bid)'
        : keywords.entries.map((e) => '  ${e.key}: ${e.value}').join('\n');

    if (!mounted) return;
    setState(() {
      _result =
          'resultCode: ${response.resultCode}\n'
          'targetingKeywords:\n$kwText\n\n'
          'Loading Ad Manager banner ($_gamAdUnitId)…';
    });

    // 2 & 3. Hand the keywords to Google Ad Manager and render.
    final bannerAd = gma.AdManagerBannerAd(
      adUnitId: _gamAdUnitId,
      sizes: [
        gma.AdSize(
          width: _adSize.width.toInt(),
          height: _adSize.height.toInt(),
        ),
      ],
      request: gma.AdManagerAdRequest(
        // The Prebid bid-winning keywords become GAM custom targeting.
        customTargeting: keywords,
      ),
      listener: gma.AdManagerBannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _bannerLoaded = true;
            _result = '$_result\n\n✅ GAM banner loaded.';
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _loading = false;
            _bannerLoaded = false;
            _result = '$_result\n\n❌ GAM load failed: ${error.message}';
          });
        },
      ),
    );
    _bannerAd = bannerAd;
    await bannerAd.load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Original API (GAM)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Prebid runs the auction (PrebidBannerAdUnit.fetchDemand), then hands '
            'its targeting keywords to the google_mobile_ads (Ad Manager) SDK '
            'for rendering.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Config: $_configId → GAM unit: $_gamAdUnitId',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          ActionButton(
            label: _loading ? 'Working…' : 'Fetch & Load',
            icon: Icons.sync_rounded,
            onPressed: _loading ? null : _fetchAndLoad,
          ),
          const SizedBox(height: 16),
          ResultPanel(text: _result),
          const SizedBox(height: 16),
          if (_bannerLoaded && _bannerAd != null)
            Center(
              child: Container(
                width: _adSize.width,
                height: _adSize.height,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: gma.AdWidget(ad: _bannerAd!),
              ),
            ),
        ],
      ),
    );
  }
}
