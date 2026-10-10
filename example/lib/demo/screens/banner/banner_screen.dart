import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';

import '../../demo_screen.dart';
import 'original_banner.dart';

/// Banner screens A1 (GAM, GAM Original, memory leak), A2 (outstream video),
/// A5 (scrollable) and A6 (declared in layout) — the original
/// `fragment_bidding_banner*` layouts.
///
/// - **In-App** (A2/A5/A6): [PrebidBannerAd].
/// - **GAM**: [PrebidGamBannerAd] with the item's GAM ad unit.
/// - **GAM Original**: Prebid auction ([OriginalBannerAd]) + Google Ad
///   Manager banner with the targeting keywords.
///
/// Layout (A1/A2): ad · `AdUnitId` label · **Load** · **Stop refresh** · the
/// 6 standard rows. A5 has the Load button first and no Stop refresh; A6 has
/// the label and rows above a single Load button.
class BannerScreen extends DemoScreen {
  const BannerScreen({super.key, required super.item});

  @override
  State<BannerScreen> createState() => _BannerScreenState();
}

class _BannerScreenState extends DemoScreenState<BannerScreen> {
  static const loaded = 'onAdLoaded called';
  static const displayed = 'onAdDisplayed called';
  static const failed = 'onAdFailed called';
  static const clicked = 'onAdClicked called';
  static const closed = 'onAdClosed called';
  static const expired = 'onAdExpired';

  late final events = EventCounters([
    loaded,
    displayed,
    failed,
    clicked,
    closed,
    expired,
  ], tag: 'Banner');

  final _controller = PrebidBannerAdController();
  final _original = GlobalKey<OriginalBannerAdState>();
  bool _loadEnabled = false;

  bool get _memoryLeak => item.has(DemoFlag.memoryLeak);
  bool get _isVideo => item.screen == ScreenType.a2;

  /// GAM and GAM Original outstream screens don't wire Stop refresh.
  bool get _stopRefreshWired =>
      !(_isVideo &&
          (item.integration == DemoIntegration.gam ||
              item.integration == DemoIntegration.original));

  @override
  AdConfiguration initialConfiguration() => AdConfiguration(
    configId: item.resolveConfigId() ?? '',
    width: item.size.width,
    height: item.size.height,
    refreshSeconds: item.refreshSeconds ?? 30,
  );

  @override
  Future<void> startAd() async {
    // The ad widget is built (and auto-loads) now that `started` is true.
  }

  int? get _refresh {
    if (item.refreshSeconds == null) return null;
    return config.refreshSeconds > 0 ? config.refreshSeconds : null;
  }

  void _load() {
    events.reset();
    setState(() => _loadEnabled = false);
    if (item.integration == DemoIntegration.original) {
      _original.currentState?.load();
    } else {
      _controller.loadAd();
    }
  }

  void _stopRefresh() {
    if (item.integration == DemoIntegration.original) {
      _original.currentState?.stopRefresh();
    } else {
      _controller.stopRefresh();
    }
    events.reset();
    setState(() => _loadEnabled = true);
  }

  void _onResult(String row, [String? detail]) {
    if (!mounted) return;
    events.reset();
    events.fire(row, detail);
    setState(() => _loadEnabled = true);
  }

  PrebidBannerAdListener? _listener() {
    if (_memoryLeak) return null;
    return PrebidBannerAdListener(
      onAdLoaded: () => _onResult(loaded),
      onAdFailed: (e) => _onResult(failed, e),
      onAdDisplayed: () => events.fire(displayed),
      onAdClicked: () => events.fire(clicked),
      onAdClosed: () => events.fire(closed),
      onAdExpired: () => events.fire(expired),
    );
  }

  Set<PrebidAdFormat>? get _formats =>
      item.adFormats ?? (_isVideo ? const {PrebidAdFormat.video} : null);

  Widget _ad() {
    switch (item.integration) {
      case DemoIntegration.gam:
        return PrebidGamBannerAd(
          configId: config.configId,
          gamAdUnitId: item.adUnitId ?? '',
          width: config.width,
          height: config.height,
          additionalSizes: item.additionalSizes,
          adFormats: _formats,
          videoParameters: item.videoParameters,
          videoPlacementType: _isVideo ? VideoPlacementType.inBanner : null,
          refreshIntervalSeconds: _refresh,
          controller: _controller,
          listener: _listener(),
        );
      case DemoIntegration.original:
        return OriginalBannerAd(
          key: _original,
          item: item,
          config: config,
          refreshSeconds: _refresh,
          onLoaded: _memoryLeak ? null : () => _onResult(loaded),
          onFailed: _memoryLeak ? null : (e) => _onResult(failed, e),
          onClicked: _memoryLeak ? null : () => events.fire(clicked),
        );
      default:
        return PrebidBannerAd(
          configId: config.configId,
          width: config.width,
          height: config.height,
          additionalSizes: item.additionalSizes,
          adFormats: _formats,
          videoParameters: item.videoParameters,
          videoPlacementType: _isVideo ? VideoPlacementType.inBanner : null,
          refreshIntervalSeconds: _refresh,
          controller: _controller,
          listener: _listener(),
        );
    }
  }

  @override
  Widget buildDemo(BuildContext context) {
    final ad = AdContainer(child: started ? _ad() : null);
    final label = item.showsAdUnitLabel
        ? AdUnitIdLabel(config.configId)
        : const SizedBox.shrink();
    final load = DemoButton('Load', onPressed: _loadEnabled ? _load : null);
    final rows = EventCounterList(counters: events);

    final children = switch (item.screen) {
      // A5: Load, the ad inside a scroll view, label, rows.
      ScreenType.a5 => [
        load,
        const SizedBox(height: 16),
        SizedBox(
          height: 320,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 120),
                ad,
                const SizedBox(height: 400),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        label,
        const SizedBox(height: 16),
        rows,
      ],
      // A6: the banner "declared in the layout", label, rows, Load.
      ScreenType.a6 => [
        ad,
        const SizedBox(height: 16),
        label,
        const SizedBox(height: 16),
        rows,
        const SizedBox(height: 16),
        load,
      ],
      _ => [
        ad,
        const SizedBox(height: 16),
        label,
        const SizedBox(height: 12),
        DemoButtonRow(
          children: [
            load,
            DemoButton(
              'Stop refresh',
              onPressed: started && _stopRefreshWired ? _stopRefresh : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        rows,
      ],
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// The GAM ad sizes for an item: its size (and the multisize extra), or
/// fluid for native-styles banners.
List<gma.AdSize> gamSizesFor(DemoItem item, AdConfiguration config) => [
  gma.AdSize(width: config.width, height: config.height),
  ...?item.additionalSizes?.map(
    (s) => gma.AdSize(width: s.width.round(), height: s.height.round()),
  ),
];
