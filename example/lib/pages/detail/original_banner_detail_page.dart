import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../../models/demo_ad_category.dart';
import '../../models/demo_ad_format.dart';
import '../../models/test_case.dart';
import '../../utils/app_settings.dart';
import '../../utils/bid_summary.dart';
import '../../widgets/action_button.dart';
import '../../widgets/ad_unit_header.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/event_counter.dart';
import '../../widgets/result_panel.dart';

/// GAM Original API banner (display or outstream video): Prebid runs the
/// auction and hands the winning targeting keywords to Google Ad Manager
/// (`google_mobile_ads`), which renders through a Prebid line item + the
/// Prebid Universal Creative.
///
/// Cases flagged [TestCase.filterUncachedBids] turn on
/// [PrebidMobile.setFilterOutUncachedBids] for the request, as in Prebid's
/// `GamOriginalApiFilterUncachedBidsBannerActivity`.
class OriginalBannerDetailPage extends StatefulWidget {
  final TestCase tc;
  const OriginalBannerDetailPage({super.key, required this.tc});

  @override
  State<OriginalBannerDetailPage> createState() =>
      _OriginalBannerDetailPageState();
}

class _OriginalBannerDetailPageState extends State<OriginalBannerDetailPage> {
  final EventTracker _tracker = EventTracker('Original');

  PrebidMultiformatAd? _adUnit;
  gma.AdManagerBannerAd? _bannerAd;
  bool _loaded = false;
  String? _result;

  bool get _isVideo => widget.tc.format == DemoAdFormat.videoBanner;

  Size get _size =>
      Size(widget.tc.width.toDouble(), widget.tc.height.toDouble());

  static const _events = [
    'fetchDemand success',
    'fetchDemand failed',
    'onAdLoaded',
    'onAdFailed',
    'onAdImpression',
    'onAdClicked',
    'onAdOpened',
    'onAdClosed',
  ];

  @override
  void dispose() {
    _bannerAd?.dispose();
    _adUnit?.destroy();
    if (widget.tc.filterUncachedBids) {
      PrebidMobile.setFilterOutUncachedBids(AppSettings.filterOutUncachedBids);
    }
    super.dispose();
  }

  Future<void> _load() async {
    _bannerAd?.dispose();
    _bannerAd = null;
    await _adUnit?.destroy();
    _tracker.reset();
    setState(() {
      _loaded = false;
      _result = null;
    });

    await PrebidMobile.clearStoredAuctionResponse();
    if (widget.tc.filterUncachedBids) {
      await PrebidMobile.setFilterOutUncachedBids(true);
    }

    // 1. Prebid auction.
    final adUnit = PrebidMultiformatAd(
      configId: widget.tc.configId,
      bannerSizes: _isVideo ? null : [_size],
      videoParameters: _isVideo
          ? const VideoParameters(
              mimes: ['video/mp4'],
              protocols: [VideoProtocol.vast2_0],
              playbackMethods: [VideoPlaybackMethod.autoPlaySoundOff],
              placement: VideoPlacement.inBanner,
            )
          : null,
    );
    _adUnit = adUnit;
    final response = await adUnit.fetchDemand();
    final keywords = response.targetingKeywords ?? const <String, String>{};
    if (response.isSuccess) {
      _tracker.track('fetchDemand success', bidSummary(response));
    } else {
      _tracker.track('fetchDemand failed', response.resultCode);
    }
    setState(() {
      _result = [
        'resultCode: ${response.resultCode}',
        if (response.exp != null) 'exp: ${response.exp}s',
        'topBidFiltered: ${response.topBidFiltered}',
        for (final e in keywords.entries) '${e.key} = ${e.value}',
      ].join('\n');
    });

    // 2. GAM request with Prebid's keywords.
    final bannerAd = gma.AdManagerBannerAd(
      adUnitId: widget.tc.adUnitId ?? '',
      sizes: [gma.AdSize(width: widget.tc.width, height: widget.tc.height)],
      request: gma.AdManagerAdRequest(customTargeting: keywords),
      listener: gma.AdManagerBannerAdListener(
        onAdLoaded: (ad) {
          _tracker.track('onAdLoaded');
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _tracker.track('onAdFailed', error.message);
        },
        onAdImpression: (_) => _tracker.track('onAdImpression'),
        onAdClicked: (_) => _tracker.track('onAdClicked'),
        onAdOpened: (_) => _tracker.track('onAdOpened'),
        onAdClosed: (_) => _tracker.track('onAdClosed'),
      ),
    );
    _bannerAd = bannerAd;
    await bannerAd.load();
  }

  @override
  Widget build(BuildContext context) {
    return AdDetailScaffold(
      title: widget.tc.title,
      tracker: _tracker,
      events: _events,
      stage: AdStage(
        hint: 'Tap Load to run the auction and render via GAM',
        child: _loaded && _bannerAd != null
            ? SizedBox(
                width: _size.width,
                height: _size.height,
                child: gma.AdWidget(ad: _bannerAd!),
              )
            : null,
      ),
      header: AdUnitHeader(
        configId: widget.tc.configId,
        category: categoryOf(widget.tc),
        integration: widget.tc.integration,
        adUnitId: widget.tc.adUnitId,
      ),
      actions: [
        ActionButton(
          label: 'Fetch & Load',
          icon: Icons.sync_rounded,
          onPressed: _load,
        ),
      ],
      extra: [if (_result != null) ResultPanel(text: _result!)],
    );
  }
}
