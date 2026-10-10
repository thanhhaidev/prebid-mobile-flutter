import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../../platform/pending_api.dart';
import '../demo_screen.dart';

/// Screen A1 for In-App banners — the original `PpmBannerFragment`
/// (`fragment_bidding_banner`) and its variants routed to A1:
/// Events (account override), Custom Renderer (+ PluginEventListener),
/// Special Symbols (app name), Server-Side Creative Factory Timeout and the
/// Rendering API Banner Memory Leak.
///
/// Layout: ad container · `AdUnitId: <configId>` · **Load** · **Stop refresh**
/// · 6 event rows.
///
/// Behaviour (spec §3 A1):
/// - the banner auto-loads on open, refresh 30 s (configurator can change);
/// - Load: reset rows, disable Load, `loadAd()`; it starts disabled and is
///   enabled by the first load result;
/// - Stop refresh: `stopRefresh()`, reset rows, enable Load;
/// - onAdLoaded / onAdFailed: reset rows, light theirs, enable Load;
/// - memory-leak item: no listener, so no row ever fires.
class InAppBannerScreen extends DemoScreen {
  const InAppBannerScreen({super.key, required super.item});

  @override
  State<InAppBannerScreen> createState() => _InAppBannerScreenState();
}

class _InAppBannerScreenState extends DemoScreenState<InAppBannerScreen> {
  static const _loaded = 'onAdLoaded called';
  static const _displayed = 'onAdDisplayed called';
  static const _failed = 'onAdFailed called';
  static const _clicked = 'onAdClicked called';
  static const _closed = 'onAdClosed called';
  static const _expired = 'onAdExpired';

  late final events = EventCounters([
    _loaded,
    _displayed,
    _failed,
    _clicked,
    _closed,
    _expired,
  ], tag: 'Banner');

  final _controller = PrebidBannerAdController();
  bool _loadEnabled = false;

  bool get _memoryLeak => item.has(DemoFlag.memoryLeak);

  @override
  Future<void> startAd() async {
    // The banner widget is built (and auto-loads) now that `started` is true.
  }

  void _load() {
    events.reset();
    setState(() => _loadEnabled = false);
    _controller.loadAd();
  }

  void _stopRefresh() {
    _controller.stopRefresh();
    events.reset();
    setState(() => _loadEnabled = true);
  }

  void _onResult(String row, [String? detail]) {
    if (!mounted) return;
    events.reset();
    events.fire(row, detail);
    setState(() => _loadEnabled = true);
  }

  Future<void> _onAdLoaded() async {
    if (item.has(DemoFlag.creativeFactoryTimeoutCheck)) {
      // Server sdk-config not applied ⇒ the SDK still has its defaults.
      final timeout = await PendingApi.getCreativeFactoryTimeout();
      final preRender =
          await PendingApi.getCreativeFactoryTimeoutPreRenderContent();
      if (timeout == 6000 || preRender == 30000) {
        _onResult(
          _failed,
          'sdk-config not applied (timeouts $timeout / $preRender)',
        );
        return;
      }
    }
    _onResult(_loaded);
  }

  PrebidBannerAdListener? _listener() {
    if (_memoryLeak) return null; // anonymous listener in the original
    return PrebidBannerAdListener(
      onAdLoaded: _onAdLoaded,
      onAdFailed: (e) => _onResult(_failed, e),
      onAdDisplayed: () => events.fire(_displayed),
      onAdClicked: () => events.fire(_clicked),
      onAdClosed: () => events.fire(_closed),
      onAdExpired: () => events.fire(_expired),
    );
  }

  @override
  Widget buildDemo(BuildContext context) {
    final refresh = config.refreshSeconds > 0 ? config.refreshSeconds : null;
    // A Column (not a ListView) so the banner's platform view is never
    // recycled while scrolling.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdContainer(
            child: started
                ? PrebidBannerAd(
                    configId: config.configId,
                    width: config.width,
                    height: config.height,
                    additionalSizes: item.additionalSizes,
                    refreshIntervalSeconds: item.refreshSeconds == null
                        ? null
                        : refresh,
                    controller: _controller,
                    listener: _listener(),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          if (item.showsAdUnitLabel) AdUnitIdLabel(config.configId),
          const SizedBox(height: 12),
          DemoButtonRow(
            children: [
              DemoButton('Load', onPressed: _loadEnabled ? _load : null),
              DemoButton(
                'Stop refresh',
                onPressed: started ? _stopRefresh : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          EventCounterList(counters: events),
        ],
      ),
    );
  }
}
