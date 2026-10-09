import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import '../../models/demo_ad_category.dart';
import '../../models/demo_ad_format.dart';
import '../../models/demo_integration.dart';
import '../../models/test_case.dart';
import '../../widgets/action_button.dart';
import '../../widgets/ad_unit_header.dart';
import '../../widgets/configure_ad_dialog.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/event_counter.dart';

/// Banner test cases (display, video, MRAID) for In-App, GAM, AdMob and MAX.
///
/// Every callback is tracked: the Prebid rendering banners (In-App / GAM)
/// report expiry and outstream-video playback events; the mediated banners
/// (AdMob / MAX) report the ad server's impression. "Stop refresh" uses
/// [PrebidBannerAdController] for In-App / GAM, and recreates the mediated
/// banners without a refresh interval.
class BannerDetailPage extends StatefulWidget {
  final TestCase tc;
  const BannerDetailPage({super.key, required this.tc});

  @override
  State<BannerDetailPage> createState() => _BannerDetailPageState();
}

class _BannerDetailPageState extends State<BannerDetailPage> {
  final EventTracker _tracker = EventTracker('Banner');

  late String _configId = widget.tc.configId;
  late int _width = widget.tc.width;
  late int _height = widget.tc.height;
  int _refreshSeconds = 0; // 0 = auto-refresh disabled

  bool _showAd = false;
  int _adKey = 0;

  final _controller = PrebidBannerAdController();

  bool get _isVideo => widget.tc.format == DemoAdFormat.videoBanner;

  DemoIntegration get _integration => widget.tc.integration;

  /// In-App and GAM banners are Prebid-rendered `BannerView`s.
  bool get _isRendering =>
      _integration == DemoIntegration.inApp ||
      _integration == DemoIntegration.gam;

  List<String> get _events => [
    'onAdLoaded',
    'onAdDisplayed',
    'onAdFailed',
    if (!_isRendering) 'onAdImpression',
    'onAdClicked',
    'onAdClosed',
    if (_isRendering) 'onAdExpired',
    if (_isRendering && _isVideo) ...[
      'onVideoCompleted',
      'onVideoPaused',
      'onVideoResumed',
      'onVideoMuted',
      'onVideoUnmuted',
    ],
  ];

  Future<void> _load() async {
    await PrebidMobile.clearStoredAuctionResponse();
    _tracker.reset();
    _tracker.track(
      'load',
      '${_integration.label} $_configId ${_width}x$_height'
          '${_refreshSeconds > 0 ? ' refresh=${_refreshSeconds}s' : ''}',
    );
    setState(() {
      _showAd = true;
      _adKey++;
    });
  }

  void _stopRefresh() {
    _tracker.track('stopRefresh');
    if (_isRendering) {
      _controller.stopRefresh();
      return;
    }
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
    onAdLoaded: () => _tracker.track('onAdLoaded'),
    onAdDisplayed: () => _tracker.track('onAdDisplayed'),
    onAdFailed: (e) => _tracker.track('onAdFailed', e),
    onAdImpression: () => _tracker.track('onAdImpression'),
    onAdClicked: () => _tracker.track('onAdClicked'),
    onAdClosed: () => _tracker.track('onAdClosed'),
    onAdExpired: () => _tracker.track('onAdExpired'),
  );

  PrebidBannerVideoListener _videoListener() => PrebidBannerVideoListener(
    onVideoCompleted: () => _tracker.track('onVideoCompleted'),
    onVideoPaused: () => _tracker.track('onVideoPaused'),
    onVideoResumed: () => _tracker.track('onVideoResumed'),
    onVideoMuted: () => _tracker.track('onVideoMuted'),
    onVideoUnmuted: () => _tracker.track('onVideoUnmuted'),
  );

  /// Builds the integration-specific banner platform-view widget.
  Widget _bannerWidget() {
    final key = ValueKey(_adKey);
    final refresh = _refreshSeconds >= 30 ? _refreshSeconds : null;
    final adUnitId = widget.tc.adUnitId ?? '';
    return switch (_integration) {
      DemoIntegration.inApp => PrebidBannerAd(
        key: key,
        configId: _configId,
        width: _width,
        height: _height,
        isVideo: _isVideo,
        refreshIntervalSeconds: refresh,
        controller: _controller,
        listener: _listener(),
        videoListener: _videoListener(),
      ),
      DemoIntegration.gam => PrebidGamBannerAd(
        key: key,
        configId: _configId,
        gamAdUnitId: adUnitId,
        width: _width,
        height: _height,
        isVideo: _isVideo,
        refreshIntervalSeconds: refresh,
        controller: _controller,
        listener: _listener(),
        videoListener: _videoListener(),
      ),
      DemoIntegration.admob => PrebidAdMobBannerAd(
        key: key,
        configId: _configId,
        adMobAdUnitId: adUnitId,
        width: _width,
        height: _height,
        listener: _listener(),
      ),
      DemoIntegration.max => PrebidMaxBannerAd(
        key: key,
        configId: _configId,
        maxAdUnitId: adUnitId,
        width: _width,
        height: _height,
        listener: _listener(),
      ),
      // Original API banners have their own page (google_mobile_ads).
      DemoIntegration.original => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AdDetailScaffold(
      title: widget.tc.title,
      tracker: _tracker,
      events: _events,
      onConfigure: _configure,
      stage: AdStage(
        child: _showAd
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _bannerWidget(),
                ),
              )
            : null,
      ),
      header: AdUnitHeader(
        configId: _configId,
        category: categoryOf(widget.tc),
        integration: _integration,
        adUnitId: widget.tc.adUnitId,
      ),
      actions: [
        ActionButton(
          label: 'Load',
          icon: Icons.play_arrow_rounded,
          onPressed: _load,
        ),
        ActionButton(
          label: 'Stop refresh',
          primary: false,
          icon: Icons.stop_rounded,
          onPressed: _showAd ? _stopRefresh : null,
        ),
      ],
    );
  }
}
