import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import '../../models/demo_ad_category.dart';
import '../../models/demo_ad_format.dart';
import '../../models/demo_integration.dart';
import '../../models/test_case.dart';
import '../../utils/logger.dart';
import '../../widgets/action_button.dart';
import '../../widgets/ad_unit_header.dart';
import '../../widgets/configure_ad_dialog.dart';
import '../../widgets/event_counter.dart';

/// Banner ad detail page — ad stage, config header, Load / Stop refresh, and
/// callback counters. Works across integrations (In-App / GAM / AdMob / MAX):
/// the platform-view widget is chosen from [TestCase.integration], all sharing
/// a [PrebidBannerAdListener]. The app-bar gear opens the "Configure" dialog.
class BannerDetailPage extends StatefulWidget {
  final TestCase tc;
  const BannerDetailPage({super.key, required this.tc});

  @override
  State<BannerDetailPage> createState() => _BannerDetailPageState();
}

class _BannerDetailPageState extends State<BannerDetailPage> {
  final EventTracker _tracker = EventTracker();
  final _log = PrebidDemoLogger.instance;

  late String _configId = widget.tc.configId;
  late int _width = widget.tc.width;
  late int _height = widget.tc.height;
  int _refreshSeconds = 0; // 0 = auto-refresh disabled

  bool _showAd = false;
  int _adKey = 0;

  bool get _isVideo => widget.tc.format == DemoAdFormat.videoBanner;

  Future<void> _load() async {
    _log.log('Banner', 'Clearing stored response');
    await PrebidMobile.clearStoredAuctionResponse();
    _tracker.reset();
    _log.log(
      'Banner',
      'Loading ${widget.tc.integration.label} '
          '${_isVideo ? "video" : "display"} banner: '
          '$_configId (${_width}x$_height, refresh=$_refreshSeconds)',
    );
    setState(() {
      _showAd = true;
      _adKey++;
    });
  }

  void _stopRefresh() {
    _log.log('Banner', 'Stopping auto-refresh');
    setState(() {
      _refreshSeconds = 0;
      _adKey++;
    });
  }

  Future<void> _configure() async {
    final cfg = await ConfigureAdDialog.show(
      context,
      initial: AdConfig(
        configId: _configId,
        width: _width,
        height: _height,
        refreshDelay: _refreshSeconds,
      ),
    );
    if (cfg == null) return;
    setState(() {
      _configId = cfg.configId;
      _width = cfg.width;
      _height = cfg.height;
      _refreshSeconds = cfg.refreshDelay;
    });
    await _load();
  }

  PrebidBannerAdListener _listener() => PrebidBannerAdListener(
    onAdLoaded: () {
      _tracker.track('onAdLoaded');
      _log.log('Banner', 'Ad loaded');
    },
    onAdDisplayed: () {
      _tracker.track('onAdDisplayed');
      _log.log('Banner', 'Ad displayed');
    },
    onAdFailed: (e) {
      _tracker.track('onAdFailed', e);
      _log.log('Banner', 'Ad failed: $e', level: LogLevel.error);
    },
    onAdClicked: () {
      _tracker.track('onAdClicked');
      _log.log('Banner', 'Ad clicked');
    },
    onAdClosed: () {
      _tracker.track('onAdClosed');
      _log.log('Banner', 'Ad closed');
    },
  );

  /// Builds the integration-specific banner platform-view widget.
  Widget _bannerWidget() {
    final key = ValueKey(_adKey);
    final refresh = _refreshSeconds >= 30 ? _refreshSeconds : null;
    final adUnitId = widget.tc.adUnitId ?? '';
    switch (widget.tc.integration) {
      case DemoIntegration.inApp:
        return PrebidBannerAd(
          key: key,
          configId: _configId,
          width: _width,
          height: _height,
          isVideo: _isVideo,
          refreshIntervalSeconds: refresh,
          listener: _listener(),
        );
      case DemoIntegration.gam:
        return PrebidGamBannerAd(
          key: key,
          configId: _configId,
          gamAdUnitId: adUnitId,
          width: _width,
          height: _height,
          isVideo: _isVideo,
          refreshIntervalSeconds: refresh,
          listener: _listener(),
        );
      case DemoIntegration.admob:
        return PrebidAdMobBannerAd(
          key: key,
          configId: _configId,
          adMobAdUnitId: adUnitId,
          width: _width,
          height: _height,
          listener: _listener(),
        );
      case DemoIntegration.max:
        return PrebidMaxBannerAd(
          key: key,
          configId: _configId,
          maxAdUnitId: adUnitId,
          width: _width,
          height: _height,
          listener: _listener(),
        );
      case DemoIntegration.original:
        // Original API banners render through google_mobile_ads — handled by a
        // dedicated page; this widget is not used for that integration.
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tc.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Configure the Ad',
            onPressed: _configure,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _tracker,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Ad stage
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
                child: _showAd
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _bannerWidget(),
                        ),
                      )
                    : Text(
                        'Tap Load to request an ad',
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
              ),
              const SizedBox(height: 16),
              AdUnitHeader(
                configId: _configId,
                category: categoryOf(widget.tc),
                integration: widget.tc.integration,
                adUnitId: widget.tc.adUnitId,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      label: 'Load',
                      icon: Icons.play_arrow_rounded,
                      onPressed: _load,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton(
                      label: 'Stop refresh',
                      primary: false,
                      icon: Icons.stop_rounded,
                      onPressed: _stopRefresh,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              EventCounterList(
                tracker: _tracker,
                events: const [
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
