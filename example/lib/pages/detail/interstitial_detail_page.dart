import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../../models/demo_ad_format.dart';
import '../../models/test_case.dart';
import '../../utils/logger.dart';
import '../../widgets/action_button.dart';
import '../../widgets/config_info_panel.dart';
import '../../widgets/event_counter.dart';
import '../../widgets/expandable_error_panel.dart';
import '../../widgets/log_viewer_panel.dart';

/// Interstitial ad detail page.
///
/// Mirrors `InAppDisplayInterstitialViewController` and `InAppVideoInterstitialViewController`.
/// Selects correct AdFormat (banner/video) based on the test case's DemoAdFormat.
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
  bool _canShow = false;
  bool _isLoading = false;
  String? _errorMessage;
  int? _loadTimeMs;
  final Stopwatch _stopwatch = Stopwatch();

  /// Pick the right AdFormat based on whether this is a video or display interstitial.
  Set<AdFormat> get _adFormats {
    return widget.tc.format == DemoAdFormat.videoInterstitial
        ? {AdFormat.video}
        : {AdFormat.banner};
  }

  Future<void> _load() async {
    _ad?.destroy();
    _tracker.reset();
    setState(() {
      _canShow = false;
      _isLoading = true;
      _errorMessage = null;
      _loadTimeMs = null;
    });
    _stopwatch.reset();
    _stopwatch.start();

    _log.log('Interstitial', 'Clearing stored response');
    await PrebidMobile.clearStoredAuctionResponse();
    if (widget.tc.storedResponse != null) {
      _log.log(
        'Interstitial',
        'Setting stored response: ${widget.tc.storedResponse}',
      );
      await PrebidMobile.setStoredAuctionResponse(widget.tc.storedResponse!);
    }

    _log.log(
      'Interstitial',
      'Loading ad: ${widget.tc.configId} formats=$_adFormats',
    );
    _ad = PrebidInterstitialAd(
      configId: widget.tc.configId,
      adFormats: _adFormats,
      listener: PrebidInterstitialAdListener(
        onAdLoaded: () {
          _stopwatch.stop();
          _tracker.track('onAdLoaded');
          _log.log(
            'Interstitial',
            'Ad loaded in ${_stopwatch.elapsedMilliseconds}ms',
          );
          setState(() {
            _canShow = true;
            _isLoading = false;
            _loadTimeMs = _stopwatch.elapsedMilliseconds;
          });
        },
        onAdFailed: (e) {
          _stopwatch.stop();
          _tracker.track('onAdFailed', e);
          _log.log(
            'Interstitial',
            'Ad failed in ${_stopwatch.elapsedMilliseconds}ms: $e',
            level: LogLevel.error,
          );
          setState(() {
            _isLoading = false;
            _errorMessage = e;
            _loadTimeMs = _stopwatch.elapsedMilliseconds;
          });
        },
        onAdDisplayed: () {
          _tracker.track('onAdDisplayed');
          _log.log('Interstitial', 'Ad displayed');
        },
        onAdDismissed: () {
          _tracker.track('onAdDismissed');
          _log.log('Interstitial', 'Ad dismissed');
          setState(() => _canShow = false);
        },
        onAdClicked: () {
          _tracker.track('onAdClicked');
          _log.log('Interstitial', 'Ad clicked');
        },
      ),
    );
    _ad!.loadAd();
  }

  @override
  void dispose() {
    _ad?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tc.title)),
      body: ListenableBuilder(
        listenable: _tracker,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Format badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.tc.format == DemoAdFormat.videoInterstitial
                      ? Colors.purple.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.tc.format == DemoAdFormat.videoInterstitial
                      ? '🎬 Video Interstitial'
                      : '🖼 Display Interstitial',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.tc.format == DemoAdFormat.videoInterstitial
                        ? Colors.purple.shade700
                        : Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Loading indicator
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Loading ad...',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

              // Error display
              if (_errorMessage != null)
                ExpandableErrorPanel(error: _errorMessage!),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ActionButton(label: 'Load', onPressed: _load),
                  const SizedBox(width: 24),
                  ActionButton(
                    label: 'Show',
                    onPressed: _canShow ? () => _ad?.show() : null,
                  ),
                ],
              ),
              const Divider(),
              EventCounterList(
                tracker: _tracker,
                events: const [
                  'onAdLoaded',
                  'onAdFailed',
                  'onAdDisplayed',
                  'onAdClicked',
                  'onAdDismissed',
                ],
              ),
              const SizedBox(height: 12),
              ConfigInfoPanel(tc: widget.tc, loadTimeMs: _loadTimeMs),
              const SizedBox(height: 12),
              const LogViewerPanel(),
            ],
          ),
        ),
      ),
    );
  }
}
