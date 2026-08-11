import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../../models/demo_ad_category.dart';
import '../../models/test_case.dart';
import '../../utils/logger.dart';
import '../../widgets/action_button.dart';
import '../../widgets/ad_unit_header.dart';
import '../../widgets/event_counter.dart';
import '../../widgets/result_panel.dart';

/// In-stream video detail page — uses [PrebidInstreamVideoAd] to fetch demand
/// and display the returned targeting keywords.
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

  Future<void> _fetchDemand() async {
    _ad?.destroy();
    _tracker.reset();
    setState(() => _resultInfo = null);

    _log.log('Video', 'Clearing stored response');
    await PrebidMobile.clearStoredAuctionResponse();
    _log.log('Video', 'Fetching demand: ${widget.tc.configId}');
    _ad = PrebidInstreamVideoAd(
      configId: widget.tc.configId,
      size: ui.Size(widget.tc.width.toDouble(), widget.tc.height.toDouble()),
    );

    final result = await _ad!.fetchDemand();
    if (result.isSuccess) {
      _tracker.track('onRequestSuccess');
      _log.log('Video', 'Demand fetched');
      final buf = StringBuffer('Targeting Keywords:\n');
      result.targetingKeywords?.forEach((k, v) => buf.writeln('  $k = $v'));
      setState(() => _resultInfo = buf.toString());
    } else {
      _tracker.track('onRequestFailed', result.resultCode);
      _log.log(
        'Video',
        'Demand failed: ${result.resultCode}',
        level: LogLevel.error,
      );
      setState(() => _resultInfo = 'Result: ${result.resultCode}');
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
              AdUnitHeader(
                configId: widget.tc.configId,
                category: categoryOf(widget.tc),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ActionButton(
                  label: 'Fetch Demand',
                  icon: Icons.cloud_download_rounded,
                  onPressed: _fetchDemand,
                ),
              ),
              const SizedBox(height: 16),
              EventCounterList(
                tracker: _tracker,
                events: const ['onRequestSuccess', 'onRequestFailed'],
              ),
              if (_resultInfo != null) ...[
                const SizedBox(height: 16),
                ResultPanel(text: _resultInfo!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
