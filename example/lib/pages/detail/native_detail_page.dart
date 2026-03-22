import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../../models/test_case.dart';
import '../../utils/logger.dart';
import '../../widgets/action_button.dart';
import '../../widgets/config_info_panel.dart';
import '../../widgets/event_counter.dart';
import '../../widgets/expandable_error_panel.dart';
import '../../widgets/log_viewer_panel.dart';
import '../../widgets/native_ad_card.dart';

/// Native ad detail page.
///
/// Mirrors `InAppNativeViewController`.
class NativeDetailPage extends StatefulWidget {
  final TestCase tc;
  const NativeDetailPage({super.key, required this.tc});

  @override
  State<NativeDetailPage> createState() => _NativeDetailPageState();
}

class _NativeDetailPageState extends State<NativeDetailPage> {
  final EventTracker _tracker = EventTracker();
  final _log = PrebidDemoLogger.instance;
  PrebidNativeAd? _ad;
  PrebidNativeAdResponse? _response;
  bool _isLoading = false;
  String? _errorMessage;
  int? _loadTimeMs;
  final Stopwatch _stopwatch = Stopwatch();

  Future<void> _load() async {
    _ad?.destroy();
    _tracker.reset();
    setState(() {
      _response = null;
      _isLoading = true;
      _errorMessage = null;
      _loadTimeMs = null;
    });
    _stopwatch.reset();
    _stopwatch.start();

    _log.log('Native', 'Clearing stored response');
    await PrebidMobile.clearStoredAuctionResponse();
    if (widget.tc.storedResponse != null) {
      _log.log(
        'Native',
        'Setting stored response: ${widget.tc.storedResponse}',
      );
      await PrebidMobile.setStoredAuctionResponse(widget.tc.storedResponse!);
    }

    _log.log('Native', 'Loading native ad: ${widget.tc.configId}');
    _ad = PrebidNativeAd(
      configId: widget.tc.configId,
      assets: const [
        NativeAsset.title(length: 90, required: true),
        NativeAsset.image(
          imageType: NativeImageType.main,
          widthMin: 200,
          heightMin: 50,
          required: true,
        ),
        NativeAsset.image(
          imageType: NativeImageType.icon,
          widthMin: 20,
          heightMin: 20,
          required: true,
        ),
        NativeAsset.data(dataType: NativeDataType.sponsored, required: true),
        NativeAsset.data(dataType: NativeDataType.desc, required: true),
        NativeAsset.data(dataType: NativeDataType.ctaText, required: true),
      ],
      eventTrackers: const [
        NativeEventTracker(
          eventType: NativeEventType.impression,
          methods: [
            NativeEventTrackingMethod.image,
            NativeEventTrackingMethod.js,
          ],
        ),
      ],
      listener: PrebidNativeAdListener(
        onAdLoaded: (response) {
          _stopwatch.stop();
          _tracker.track('onAdLoaded');
          _log.log(
            'Native',
            'Ad loaded in ${_stopwatch.elapsedMilliseconds}ms: title="${response.title}"',
          );
          setState(() {
            _response = response;
            _isLoading = false;
            _loadTimeMs = _stopwatch.elapsedMilliseconds;
          });
        },
        onAdFailed: (e) {
          _stopwatch.stop();
          _tracker.track('onAdFailed', e);
          _log.log(
            'Native',
            'Ad failed in ${_stopwatch.elapsedMilliseconds}ms: $e',
            level: LogLevel.error,
          );
          setState(() {
            _isLoading = false;
            _errorMessage = e;
            _loadTimeMs = _stopwatch.elapsedMilliseconds;
          });
        },
        onAdImpression: () {
          _tracker.track('onAdImpression');
          _log.log('Native', 'Ad impression tracked');
        },
        onAdClicked: () {
          _tracker.track('onAdClicked');
          _log.log('Native', 'Ad clicked');
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
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '🧩 Native Ad',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Native ad card
              if (_response != null) ...[
                NativeAdCard(response: _response!),
                const SizedBox(height: 12),
              ],

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
                        'Loading native ad...',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

              // Error display
              if (_errorMessage != null)
                ExpandableErrorPanel(error: _errorMessage!),

              ActionButton(label: 'Load', onPressed: _isLoading ? null : _load),
              const Divider(),
              EventCounterList(
                tracker: _tracker,
                events: const [
                  'onAdLoaded',
                  'onAdFailed',
                  'onAdImpression',
                  'onAdClicked',
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
