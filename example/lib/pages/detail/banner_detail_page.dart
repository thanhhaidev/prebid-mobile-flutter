import 'package:flutter/material.dart';
import 'package:prebid_mobile_flutter/prebid_mobile_flutter.dart';

import '../../models/demo_ad_format.dart';
import '../../models/test_case.dart';
import '../../utils/logger.dart';
import '../../widgets/action_button.dart';
import '../../widgets/config_info_panel.dart';
import '../../widgets/event_counter.dart';
import '../../widgets/expandable_error_panel.dart';
import '../../widgets/log_viewer_panel.dart';

/// Banner ad detail page.
///
/// Mirrors `InAppDisplayBannerViewController` and `InAppVideoBannerViewController`.
/// Sets `isVideo: true` for video banner test cases.
class BannerDetailPage extends StatefulWidget {
  final TestCase tc;
  const BannerDetailPage({super.key, required this.tc});

  @override
  State<BannerDetailPage> createState() => _BannerDetailPageState();
}

class _BannerDetailPageState extends State<BannerDetailPage> {
  final EventTracker _tracker = EventTracker();
  final _log = PrebidDemoLogger.instance;
  bool _showAd = false;
  bool _isLoading = false;
  String? _errorMessage;
  int _adKey = 0;
  int? _loadTimeMs;
  final Stopwatch _stopwatch = Stopwatch();

  bool get _isVideo => widget.tc.format == DemoAdFormat.videoBanner;

  Future<void> _load() async {
    _log.log('Banner', 'Clearing stored response');
    await PrebidMobile.clearStoredAuctionResponse();
    if (widget.tc.storedResponse != null) {
      _log.log(
        'Banner',
        'Setting stored response: ${widget.tc.storedResponse}',
      );
      await PrebidMobile.setStoredAuctionResponse(widget.tc.storedResponse!);
    }
    _tracker.reset();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadTimeMs = null;
    });
    _stopwatch.reset();
    _stopwatch.start();
    _log.log(
      'Banner',
      'Loading ${_isVideo ? "video" : "display"} banner: ${widget.tc.configId} (${widget.tc.width}x${widget.tc.height})',
    );
    setState(() {
      _showAd = true;
      _adKey++;
    });
  }

  void _hide() {
    _log.log('Banner', 'Hiding banner');
    setState(() {
      _showAd = false;
      _isLoading = false;
    });
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
                  color: _isVideo ? Colors.purple.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isVideo ? '🎬 Video Banner' : '🖼 Display Banner',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isVideo
                        ? Colors.purple.shade700
                        : Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Ad area
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_showAd)
                      PrebidBannerAd(
                        key: ValueKey(_adKey),
                        configId: widget.tc.configId,
                        width: widget.tc.width,
                        height: widget.tc.height,
                        isVideo: _isVideo,
                        listener: PrebidBannerAdListener(
                          onAdLoaded: () {
                            _stopwatch.stop();
                            _tracker.track('onAdLoaded');
                            _log.log(
                              'Banner',
                              'Ad loaded in ${_stopwatch.elapsedMilliseconds}ms',
                            );
                            setState(() {
                              _isLoading = false;
                              _loadTimeMs = _stopwatch.elapsedMilliseconds;
                            });
                          },
                          onAdFailed: (e) {
                            _stopwatch.stop();
                            _tracker.track('onAdFailed', e);
                            _log.log(
                              'Banner',
                              'Ad failed in ${_stopwatch.elapsedMilliseconds}ms: $e',
                              level: LogLevel.error,
                            );
                            setState(() {
                              _isLoading = false;
                              _errorMessage = e;
                              _loadTimeMs = _stopwatch.elapsedMilliseconds;
                            });
                          },
                          onAdClicked: () {
                            _tracker.track('onAdClicked');
                            _log.log('Banner', 'Ad clicked');
                          },
                        ),
                      )
                    else
                      SizedBox(
                        width: widget.tc.width.toDouble(),
                        height: widget.tc.height.toDouble(),
                        child: const Center(
                          child: Text(
                            'Tap "Load" to load ad',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      ),
                    if (_isLoading)
                      SizedBox(
                        width: widget.tc.width.toDouble(),
                        height: widget.tc.height.toDouble(),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Error display
              if (_errorMessage != null)
                ExpandableErrorPanel(error: _errorMessage!),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ActionButton(label: 'Load', onPressed: _load),
                  const SizedBox(width: 24),
                  ActionButton(label: 'Hide', onPressed: _hide),
                ],
              ),
              const Divider(),
              EventCounterList(
                tracker: _tracker,
                events: const ['onAdLoaded', 'onAdFailed', 'onAdClicked'],
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
