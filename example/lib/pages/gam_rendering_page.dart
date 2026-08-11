import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';

import '../widgets/action_button.dart';
import '../widgets/result_panel.dart';

/// Demonstrates the **GAM rendering** integration (companion package
/// `prebid_mobile_sdk_gam`): Prebid runs the auction and Google Ad Manager
/// renders the ad via Prebid's GAM event handlers. Uses Prebid's public demo
/// GAM ad units.
class GamRenderingPage extends StatefulWidget {
  const GamRenderingPage({super.key});

  @override
  State<GamRenderingPage> createState() => _GamRenderingPageState();
}

class _GamRenderingPageState extends State<GamRenderingPage> {
  // Prebid public demo GAM ad units (line items target the hb_* keys).
  static const _bannerConfigId = 'prebid-demo-banner-320-50';
  static const _bannerGamUnit = '/21808260008/prebid_oxb_320x50_banner';
  static const _interstitialConfigId =
      'prebid-demo-display-interstitial-320-480';
  static const _interstitialGamUnit =
      '/21808260008/prebid_oxb_html_interstitial';

  String _bannerStatus = 'Loading banner…';

  PrebidGamInterstitialAd? _interstitial;
  String _interstitialStatus = 'Idle. Tap "Load Interstitial".';
  bool _interstitialLoading = false;

  @override
  void dispose() {
    _interstitial?.destroy();
    super.dispose();
  }

  void _loadInterstitial() {
    setState(() {
      _interstitialLoading = true;
      _interstitialStatus = 'Loading interstitial…';
    });

    final ad = PrebidGamInterstitialAd(
      configId: _interstitialConfigId,
      gamAdUnitId: _interstitialGamUnit,
      listener: PrebidInterstitialAdListener(
        onAdLoaded: () {
          if (!mounted) return;
          setState(() {
            _interstitialLoading = false;
            _interstitialStatus = '✅ Loaded. Tap "Show Interstitial".';
          });
        },
        onAdFailed: (error) {
          if (!mounted) return;
          setState(() {
            _interstitialLoading = false;
            _interstitialStatus = '❌ Failed: $error';
          });
        },
        onAdDisplayed: () {
          if (!mounted) return;
          setState(() => _interstitialStatus = 'Displayed.');
        },
        onAdClosed: () {
          if (!mounted) return;
          setState(() => _interstitialStatus = 'Closed.');
          _interstitial?.destroy();
          _interstitial = null;
        },
      ),
    );
    _interstitial = ad;
    ad.loadAd();
  }

  Future<void> _showInterstitial() async {
    if (_interstitial?.isLoaded ?? false) {
      await _interstitial!.show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('GAM Rendering')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Prebid runs the auction; Google Ad Manager renders the ad via '
            'Prebid GAM event handlers (companion package prebid_mobile_sdk_gam).',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          Text('Banner', style: theme.textTheme.titleMedium),
          Text(
            '$_bannerConfigId → $_bannerGamUnit',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: PrebidGamBannerAd(
              configId: _bannerConfigId,
              gamAdUnitId: _bannerGamUnit,
              width: 320,
              height: 50,
              listener: PrebidBannerAdListener(
                onAdLoaded: () {
                  if (mounted) {
                    setState(() => _bannerStatus = '✅ Banner loaded.');
                  }
                },
                onAdFailed: (error) {
                  if (mounted) {
                    setState(() => _bannerStatus = '❌ Banner failed: $error');
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          ResultPanel(text: _bannerStatus),

          const SizedBox(height: 24),
          Text('Interstitial', style: theme.textTheme.titleMedium),
          Text(
            '$_interstitialConfigId → $_interstitialGamUnit',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ActionButton(
                  label: _interstitialLoading
                      ? 'Loading…'
                      : 'Load Interstitial',
                  icon: Icons.download_rounded,
                  onPressed: _interstitialLoading ? null : _loadInterstitial,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ActionButton(
                  label: 'Show Interstitial',
                  icon: Icons.fullscreen_rounded,
                  primary: false,
                  onPressed: _showInterstitial,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ResultPanel(text: _interstitialStatus),
        ],
      ),
    );
  }
}
