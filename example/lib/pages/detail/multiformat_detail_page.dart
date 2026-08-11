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

/// Multiformat ad detail page — fetches banner + video + native demand on a
/// single ad unit and shows the winning format and targeting keywords.
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

  Future<void> _fetchDemand() async {
    _ad?.destroy();
    _tracker.reset();
    setState(() => _resultInfo = null);

    _log.log('Multiformat', 'Clearing stored response');
    await PrebidMobile.clearStoredAuctionResponse();
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
    if (result.isSuccess) {
      _tracker.track('onRequestSuccess');
      _log.log('Multiformat', 'Demand fetched: format=${result.winningFormat}');
      final buf = StringBuffer();
      buf.writeln('Winning Format: ${result.winningFormat ?? "unknown"}');
      if (result.nativeAdCacheId != null) {
        buf.writeln('Native Cache ID: ${result.nativeAdCacheId}');
      }
      buf.writeln('Targeting Keywords:');
      result.targetingKeywords?.forEach((k, v) => buf.writeln('  $k = $v'));
      setState(() => _resultInfo = buf.toString());
    } else {
      _tracker.track('onRequestFailed', result.resultCode);
      _log.log(
        'Multiformat',
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
