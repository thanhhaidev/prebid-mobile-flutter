import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import '../../models/demo_ad_category.dart';
import '../../models/demo_ad_format.dart';
import '../../models/demo_integration.dart';
import '../../models/test_case.dart';
import '../../utils/logger.dart';
import '../../widgets/action_button.dart';
import '../../widgets/ad_unit_header.dart';
import '../../widgets/configure_ad_dialog.dart';
import '../../widgets/event_counter.dart';

/// Interstitial ad detail page — Load then Show, with callback counters. Works
/// across integrations (In-App / GAM / AdMob / MAX): the concrete ad object is
/// chosen from [TestCase.integration], but all expose loadAd/show/destroy and a
/// [PrebidInterstitialAdListener].
class InterstitialDetailPage extends StatefulWidget {
  final TestCase tc;
  const InterstitialDetailPage({super.key, required this.tc});

  @override
  State<InterstitialDetailPage> createState() => _InterstitialDetailPageState();
}

class _InterstitialDetailPageState extends State<InterstitialDetailPage> {
  final EventTracker _tracker = EventTracker();
  final _log = PrebidDemoLogger.instance;

  late String _configId = widget.tc.configId;
  bool _canShow = false;

  // Decouple the page from the concrete ad type across integrations.
  Future<void> Function()? _show;
  Future<void> Function()? _destroy;

  bool get _isVideo => widget.tc.format == DemoAdFormat.videoInterstitial;

  PrebidInterstitialAdListener _buildListener() => PrebidInterstitialAdListener(
    onAdLoaded: () {
      _tracker.track('onAdLoaded');
      _log.log('Interstitial', 'Ad loaded');
      if (mounted) setState(() => _canShow = true);
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
      if (mounted) setState(() => _canShow = false);
    },
  );

  Future<void> _load() async {
    await _destroy?.call();
    _tracker.reset();
    setState(() => _canShow = false);
    _log.log('Interstitial', 'Clearing stored response');
    await PrebidMobile.clearStoredAuctionResponse();
    _log.log(
      'Interstitial',
      'Loading ${widget.tc.integration.label}: $_configId (video=$_isVideo)',
    );

    final listener = _buildListener();
    final adUnitId = widget.tc.adUnitId ?? '';

    switch (widget.tc.integration) {
      case DemoIntegration.inApp:
        final ad = PrebidInterstitialAd(
          configId: _configId,
          adFormats: _isVideo ? {AdFormat.video} : {AdFormat.banner},
          listener: listener,
        );
        _show = ad.show;
        _destroy = ad.destroy;
        ad.loadAd();
      case DemoIntegration.gam:
        final ad = PrebidGamInterstitialAd(
          configId: _configId,
          gamAdUnitId: adUnitId,
          listener: listener,
        );
        _show = ad.show;
        _destroy = ad.destroy;
        ad.loadAd();
      case DemoIntegration.admob:
        final ad = PrebidAdMobInterstitialAd(
          configId: _configId,
          adMobAdUnitId: adUnitId,
          isVideo: _isVideo,
          listener: listener,
        );
        _show = ad.show;
        _destroy = ad.destroy;
        ad.loadAd();
      case DemoIntegration.max:
        final ad = PrebidMaxInterstitialAd(
          configId: _configId,
          maxAdUnitId: adUnitId,
          isVideo: _isVideo,
          listener: listener,
        );
        _show = ad.show;
        _destroy = ad.destroy;
        ad.loadAd();
      case DemoIntegration.original:
        // Original API interstitial is not wired in the demo yet.
        break;
    }
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
    _destroy?.call();
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
                integration: widget.tc.integration,
                adUnitId: widget.tc.adUnitId,
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
                      onPressed: _canShow ? () => _show?.call() : null,
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
