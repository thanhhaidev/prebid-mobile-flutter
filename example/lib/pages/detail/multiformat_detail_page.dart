import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../../models/test_case.dart';
import '../../utils/logger.dart';
import '../../widgets/action_button.dart';
import '../../widgets/config_info_panel.dart';
import '../../widgets/event_counter.dart';
import '../../widgets/log_viewer_panel.dart';

/// Multiformat ad detail page.
///
/// Fetches demand for banner + video + native simultaneously.
class MultiformatDetailPage extends StatefulWidget {
  final TestCase tc;
  const MultiformatDetailPage({super.key, required this.tc});

  @override
  State<MultiformatDetailPage> createState() => _MultiformatDetailPageState();
}

class _MultiformatDetailPageState extends State<MultiformatDetailPage> {
  final EventTracker _tracker = EventTracker();
  final _log = PrebidDemoLogger.instance;
  PrebidMultiformatAd? _ad;
  String? _resultInfo;
  int? _loadTimeMs;
  final Stopwatch _stopwatch = Stopwatch();

  Future<void> _fetchDemand() async {
    _ad?.destroy();
    _tracker.reset();
    setState(() {
      _resultInfo = null;
      _loadTimeMs = null;
    });
    _stopwatch.reset();
    _stopwatch.start();

    _log.log('Multiformat', 'Clearing stored response');
    await PrebidMobile.clearStoredAuctionResponse();
    if (widget.tc.storedResponse != null) {
      _log.log(
        'Multiformat',
        'Setting stored response: ${widget.tc.storedResponse}',
      );
      await PrebidMobile.setStoredAuctionResponse(widget.tc.storedResponse!);
    }

    _log.log('Multiformat', 'Fetching demand: ${widget.tc.configId}');
    _ad = PrebidMultiformatAd(
      configId: widget.tc.configId,
      bannerSizes: [
        ui.Size(widget.tc.width.toDouble(), widget.tc.height.toDouble()),
      ],
      videoParameters: const VideoParameters(mimes: ['video/mp4']),
      nativeAssets: const [
        NativeAsset.title(length: 90, required: true),
        NativeAsset.image(imageType: NativeImageType.main, required: true),
        NativeAsset.data(dataType: NativeDataType.sponsored, required: true),
        NativeAsset.data(dataType: NativeDataType.ctaText),
      ],
    );

    final result = await _ad!.fetchDemand();
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsedMilliseconds;
    if (result.isSuccess) {
      _tracker.track('onRequestSuccess');
      _log.log(
        'Multiformat',
        'Demand fetched in ${elapsed}ms: format=${result.winningFormat}',
      );
      final buf = StringBuffer();
      buf.writeln('Winning Format: ${result.winningFormat ?? "unknown"}');
      if (result.nativeAdCacheId != null) {
        buf.writeln('Native Cache ID: ${result.nativeAdCacheId}');
      }
      buf.writeln('Targeting Keywords:');
      result.targetingKeywords?.forEach((k, v) => buf.writeln('  $k = $v'));
      setState(() {
        _resultInfo = buf.toString();
        _loadTimeMs = elapsed;
      });
    } else {
      _tracker.track('onRequestFailed', result.resultCode);
      _log.log(
        'Multiformat',
        'Demand failed in ${elapsed}ms: ${result.resultCode}',
        level: LogLevel.error,
      );
      setState(() {
        _resultInfo = 'Result: ${result.resultCode}';
        _loadTimeMs = elapsed;
      });
    }
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
              Text(
                'AdUnitId: ${widget.tc.configId}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              ActionButton(label: 'Fetch Demand', onPressed: _fetchDemand),
              const Divider(),
              EventCounterList(
                tracker: _tracker,
                events: const ['onRequestSuccess', 'onRequestFailed'],
              ),
              if (_resultInfo != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _resultInfo!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
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
