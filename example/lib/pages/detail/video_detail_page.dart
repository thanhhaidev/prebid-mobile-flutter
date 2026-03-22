import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../../models/test_case.dart';
import '../../utils/logger.dart';
import '../../widgets/action_button.dart';
import '../../widgets/config_info_panel.dart';
import '../../widgets/event_counter.dart';
import '../../widgets/log_viewer_panel.dart';

/// In-stream video detail page.
///
/// Uses `PrebidInstreamVideoAd` to fetch demand and display targeting keywords.
class VideoDetailPage extends StatefulWidget {
  final TestCase tc;
  const VideoDetailPage({super.key, required this.tc});

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  final EventTracker _tracker = EventTracker();
  final _log = PrebidDemoLogger.instance;
  PrebidInstreamVideoAd? _ad;
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

    _log.log('Video', 'Clearing stored response');
    await PrebidMobile.clearStoredAuctionResponse();
    if (widget.tc.storedResponse != null) {
      _log.log('Video', 'Setting stored response: ${widget.tc.storedResponse}');
      await PrebidMobile.setStoredAuctionResponse(widget.tc.storedResponse!);
    }

    _log.log(
      'Video',
      'Fetching demand: ${widget.tc.configId} (${widget.tc.width}x${widget.tc.height})',
    );
    _ad = PrebidInstreamVideoAd(
      configId: widget.tc.configId,
      size: ui.Size(widget.tc.width.toDouble(), widget.tc.height.toDouble()),
    );

    final result = await _ad!.fetchDemand();
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsedMilliseconds;
    if (result.isSuccess) {
      _tracker.track('onRequestSuccess');
      _log.log('Video', 'Demand fetched in ${elapsed}ms');
      final buf = StringBuffer('Targeting Keywords:\n');
      result.targetingKeywords?.forEach((k, v) => buf.writeln('  $k = $v'));
      setState(() {
        _resultInfo = buf.toString();
        _loadTimeMs = elapsed;
      });
    } else {
      _tracker.track('onRequestFailed', result.resultCode);
      _log.log(
        'Video',
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
              Text(
                'Size: ${widget.tc.width}x${widget.tc.height}',
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
