import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../../models/demo_ad_category.dart';
import '../../models/demo_ad_format.dart';
import '../../models/test_case.dart';
import '../../utils/bid_summary.dart';
import '../../widgets/action_button.dart';
import '../../widgets/ad_unit_header.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/event_counter.dart';
import '../../widgets/result_panel.dart';

/// Fetch-demand-only test cases: **multiformat** (banner + video + native on
/// one `PrebidAdUnit`) and **in-stream video** (keywords for a video player /
/// IMA ad tag). Shows the result code, winning format, bid expiry,
/// `topBidFiltered` and the targeting keywords.
class DemandDetailPage extends StatefulWidget {
  final TestCase tc;
  const DemandDetailPage({super.key, required this.tc});

  @override
  State<DemandDetailPage> createState() => _DemandDetailPageState();
}

class _DemandDetailPageState extends State<DemandDetailPage> {
  late final EventTracker _tracker = EventTracker(
    _isInstream ? 'In-stream' : 'Multiformat',
  );
  Future<void> Function()? _destroy;
  String? _result;

  bool get _isInstream => widget.tc.format == DemoAdFormat.videoInstream;

  static const _events = ['fetchDemand success', 'fetchDemand failed'];

  Future<void> _fetchDemand() async {
    await _destroy?.call();
    _tracker.reset();
    setState(() => _result = null);
    await PrebidMobile.clearStoredAuctionResponse();

    final PrebidMultiformatBidResponse result;
    if (_isInstream) {
      final ad = PrebidInstreamVideoAd(
        configId: widget.tc.configId,
        size: ui.Size(widget.tc.width.toDouble(), widget.tc.height.toDouble()),
      );
      _destroy = ad.destroy;
      final video = await ad.fetchDemand();
      result = PrebidMultiformatBidResponse(
        resultCode: video.resultCode,
        winningFormat: 'video',
        targetingKeywords: video.targetingKeywords,
      );
    } else {
      final ad = PrebidMultiformatAd(
        configId: widget.tc.configId,
        gpid: '/21808260008/prebid-demo-multiformat',
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
      _destroy = ad.destroy;
      result = await ad.fetchDemand();
    }

    if (result.isSuccess) {
      _tracker.track('fetchDemand success', bidSummary(result));
    } else {
      _tracker.track('fetchDemand failed', result.resultCode);
    }
    setState(() {
      _result = [
        'resultCode: ${result.resultCode}',
        if (result.winningFormat != null)
          'winningFormat: ${result.winningFormat}',
        if (result.exp != null) 'exp: ${result.exp}s',
        'topBidFiltered: ${result.topBidFiltered}',
        if (result.nativeAdCacheId != null)
          'nativeAdCacheId: ${result.nativeAdCacheId}',
        if (result.targetingKeywords?.isNotEmpty ?? false) 'keywords:',
        for (final e
            in result.targetingKeywords?.entries ??
                const <MapEntry<String, String>>[])
          '  ${e.key} = ${e.value}',
      ].join('\n');
    });
  }

  @override
  void dispose() {
    _destroy?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdDetailScaffold(
      title: widget.tc.title,
      tracker: _tracker,
      events: _events,
      header: AdUnitHeader(
        configId: widget.tc.configId,
        category: categoryOf(widget.tc),
        integration: widget.tc.integration,
      ),
      actions: [
        ActionButton(
          label: 'Fetch Demand',
          icon: Icons.cloud_download_rounded,
          onPressed: _fetchDemand,
        ),
      ],
      extra: [if (_result != null) ResultPanel(text: _result!)],
    );
  }
}
