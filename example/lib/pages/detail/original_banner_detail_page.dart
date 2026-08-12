import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../../models/demo_ad_category.dart';
import '../../models/test_case.dart';
import '../../utils/logger.dart';
import '../../widgets/action_button.dart';
import '../../widgets/ad_unit_header.dart';
import '../../widgets/event_counter.dart';

/// Original-API banner detail page: Prebid runs the auction
/// ([PrebidBannerAdUnit.fetchDemand]) and hands the winning targeting keywords
/// to Google Ad Manager (`google_mobile_ads`), which renders through a Prebid
/// line item + the Prebid Universal Creative.
class OriginalBannerDetailPage extends StatefulWidget {
  final TestCase tc;
  const OriginalBannerDetailPage({super.key, required this.tc});

  @override
  State<OriginalBannerDetailPage> createState() =>
      _OriginalBannerDetailPageState();
}

class _OriginalBannerDetailPageState extends State<OriginalBannerDetailPage> {
  final EventTracker _tracker = EventTracker();
  final _log = PrebidDemoLogger.instance;

  PrebidBannerAdUnit? _adUnit;
  gma.AdManagerBannerAd? _bannerAd;
  bool _loaded = false;

  Size get _size =>
      Size(widget.tc.width.toDouble(), widget.tc.height.toDouble());

  @override
  void dispose() {
    _bannerAd?.dispose();
    _adUnit?.destroy();
    super.dispose();
  }

  Future<void> _load() async {
    _bannerAd?.dispose();
    _bannerAd = null;
    await _adUnit?.destroy();
    _tracker.reset();
    setState(() => _loaded = false);

    await PrebidMobile.clearStoredAuctionResponse();
    _log.log('Original', 'fetchDemand: ${widget.tc.configId} ($_size)');

    final adUnit = PrebidBannerAdUnit(
      configId: widget.tc.configId,
      sizes: [_size],
    );
    _adUnit = adUnit;

    final PrebidBidResponse response;
    try {
      response = await adUnit.fetchDemand();
    } catch (e) {
      _tracker.track('onAdFailed', '$e');
      _log.log('Original', 'fetchDemand failed: $e', level: LogLevel.error);
      return;
    }
    _tracker.track('fetchDemand');
    final keywords = response.targetingKeywords ?? const {};
    _log.log('Original', 'resultCode=${response.resultCode} kw=$keywords');

    final bannerAd = gma.AdManagerBannerAd(
      adUnitId: widget.tc.adUnitId ?? '',
      sizes: [gma.AdSize(width: widget.tc.width, height: widget.tc.height)],
      request: gma.AdManagerAdRequest(customTargeting: keywords),
      listener: gma.AdManagerBannerAdListener(
        onAdLoaded: (ad) {
          _tracker.track('onAdLoaded');
          _log.log('Original', 'GAM banner loaded');
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _tracker.track('onAdFailed', error.message);
          _log.log(
            'Original',
            'GAM load failed: ${error.message}',
            level: LogLevel.error,
          );
        },
        onAdClicked: (ad) => _tracker.track('onAdClicked'),
        onAdOpened: (ad) => _tracker.track('onAdDisplayed'),
        onAdClosed: (ad) => _tracker.track('onAdClosed'),
      ),
    );
    _bannerAd = bannerAd;
    await bannerAd.load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.tc.title)),
      body: ListenableBuilder(
        listenable: _tracker,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 120),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _loaded && _bannerAd != null
                    ? SizedBox(
                        width: _size.width,
                        height: _size.height,
                        child: gma.AdWidget(ad: _bannerAd!),
                      )
                    : Text(
                        'Tap Load to run the auction and render via GAM',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
              ),
              const SizedBox(height: 16),
              AdUnitHeader(
                configId: widget.tc.configId,
                category: categoryOf(widget.tc),
                integration: widget.tc.integration,
                adUnitId: widget.tc.adUnitId,
              ),
              const SizedBox(height: 16),
              ActionButton(
                label: 'Fetch & Load',
                icon: Icons.sync_rounded,
                onPressed: _load,
              ),
              const SizedBox(height: 16),
              EventCounterList(
                tracker: _tracker,
                events: const [
                  'fetchDemand',
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
