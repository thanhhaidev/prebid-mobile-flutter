import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../../models/demo_ad_category.dart';
import '../../models/demo_ad_format.dart';
import '../../models/test_case.dart';
import '../../utils/logger.dart';
import '../../widgets/action_button.dart';
import '../../widgets/ad_unit_header.dart';
import '../../widgets/configure_ad_dialog.dart';
import '../../widgets/event_counter.dart';

/// Interstitial ad detail page — Load then Show, with callback counters.
class InterstitialDetailPage extends StatefulWidget {
  final TestCase tc;
  const InterstitialDetailPage({super.key, required this.tc});

  @override
  State<InterstitialDetailPage> createState() => _InterstitialDetailPageState();
}

class _InterstitialDetailPageState extends State<InterstitialDetailPage> {
  final EventTracker _tracker = EventTracker();
  final _log = PrebidDemoLogger.instance;
  PrebidInterstitialAd? _ad;
  late String _configId = widget.tc.configId;
  bool _canShow = false;

  Set<AdFormat> get _adFormats =>
      widget.tc.format == DemoAdFormat.videoInterstitial
      ? {AdFormat.video}
      : {AdFormat.banner};

  Future<void> _load() async {
    _ad?.destroy();
    _tracker.reset();
    setState(() => _canShow = false);
    _log.log('Interstitial', 'Clearing stored response');
    await PrebidMobile.clearStoredAuctionResponse();
    _log.log('Interstitial', 'Loading: $_configId formats=$_adFormats');
    _ad = PrebidInterstitialAd(
      configId: _configId,
      adFormats: _adFormats,
      listener: PrebidInterstitialAdListener(
        onAdLoaded: () {
          _tracker.track('onAdLoaded');
          _log.log('Interstitial', 'Ad loaded');
          setState(() => _canShow = true);
        },
        onAdFailed: (e) {
          _tracker.track('onAdFailed', e);
          _log.log('Interstitial', 'Ad failed: $e', level: LogLevel.error);
        },
        onAdDisplayed: () {
          _tracker.track('onAdDisplayed');
          _log.log('Interstitial', 'Ad displayed');
        },
        onAdClicked: () {
          _tracker.track('onAdClicked');
          _log.log('Interstitial', 'Ad clicked');
        },
        onAdClosed: () {
          _tracker.track('onAdClosed');
          _log.log('Interstitial', 'Ad closed');
          setState(() => _canShow = false);
        },
      ),
    );
    _ad!.loadAd();
  }

  Future<void> _configure() async {
    final cfg = await ConfigureAdDialog.show(
      context,
      initial: AdConfig(
        configId: _configId,
        width: 0,
        height: 0,
        refreshDelay: 0,
      ),
      showSize: false,
      showRefresh: false,
    );
    if (cfg == null) return;
    setState(() => _configId = cfg.configId);
    await _load();
  }

  @override
  void dispose() {
    _ad?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tc.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Configure the Ad',
            onPressed: _configure,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _tracker,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AdUnitHeader(
                configId: _configId,
                category: categoryOf(widget.tc),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      label: 'Load',
                      icon: Icons.download_rounded,
                      onPressed: _load,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton(
                      label: 'Show',
                      primary: false,
                      icon: Icons.open_in_full_rounded,
                      onPressed: _canShow ? () => _ad?.show() : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              EventCounterList(
                tracker: _tracker,
                events: const [
                  'onAdLoaded',
                  'onAdDisplayed',
                  'onAdFailed',
                  'onAdClicked',
                  'onAdClosed',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
