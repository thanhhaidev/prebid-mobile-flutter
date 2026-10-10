import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';

import '../../demo_screen.dart';
import '../shared/native_request.dart';

/// Screens B1 (interstitial) and B2 (rewarded) for In-App, GAM and GAM
/// Original — the original `fragment_bidding_interstitial` /
/// `fragment_bidding_rewarded` and their fragments.
///
/// One button drives the state, as the original: **Load** → disabled, rows
/// reset, load; `onAdLoaded` → **Show**; **Show** → back to **Load** and
/// `show()`; `onAdFailed` re-enables it; `onAdExpired` → **Load**. The ad
/// loads on open. Memory-leak screens show the ad as soon as it loads and
/// leave the button unwired. GAM Original screens only report Loaded / Failed
/// (from the GMA load callbacks).
class FullscreenScreen extends DemoScreen {
  const FullscreenScreen({super.key, required super.item});

  @override
  State<FullscreenScreen> createState() => _FullscreenScreenState();
}

class _FullscreenScreenState extends DemoScreenState<FullscreenScreen> {
  static const loaded = 'onAdLoaded called';
  static const displayed = 'onAdDisplayed called';
  static const failed = 'onAdFailed called';
  static const clicked = 'onAdClicked called';
  static const closed = 'onAdClosed called';
  static const rewarded = 'onUserRewarded called';
  static const expired = 'onAdExpired';

  bool get _isRewarded => item.screen == ScreenType.b2;
  bool get _memoryLeak => item.has(DemoFlag.memoryLeak);

  late final events = EventCounters([
    loaded,
    displayed,
    failed,
    clicked,
    closed,
    if (_isRewarded) rewarded,
    expired,
  ], tag: _isRewarded ? 'Rewarded' : 'Interstitial');

  _FullscreenAd? _ad;
  String _buttonText = 'Load';
  bool _buttonEnabled = false;

  @override
  Future<void> startAd() async => _load();

  /// The min size percentage: the configurator's / item's percentages for
  /// interstitials that pass them, else the item's explicit value.
  Size? get _minSize => item.size.isMinSizePercentage
      ? Size(config.width.toDouble(), config.height.toDouble())
      : item.minSizePercentage;

  PrebidFullscreenControls? get _controls {
    final c = item.controls;
    final min = _minSize;
    if (min == null) return c;
    return PrebidFullscreenControls(
      closeButtonArea: c?.closeButtonArea,
      closeButtonPosition: c?.closeButtonPosition,
      skipButtonArea: c?.skipButtonArea,
      skipButtonPosition: c?.skipButtonPosition,
      skipDelay: c?.skipDelay,
      isMuted: c?.isMuted,
      isSoundButtonVisible: c?.isSoundButtonVisible,
      isAutoCloseOnCompletionEnabled: c?.isAutoCloseOnCompletionEnabled,
      minSizePercentage: min,
      supportSKOverlay: c?.supportSKOverlay,
    );
  }

  void _setButton(String text, bool enabled) {
    if (!mounted) return;
    setState(() {
      _buttonText = text;
      _buttonEnabled = enabled;
    });
  }

  void _onLoaded() {
    if (!mounted) return;
    events.fire(loaded);
    if (_memoryLeak) {
      _ad?.show();
      return;
    }
    _setButton('Show', true);
  }

  void _onFailed(String error) {
    events.fire(failed, error);
    _setButton(_buttonText, true);
  }

  Future<void> _load() async {
    events.reset();
    _setButton('Load', false);
    await _ad?.destroy();
    final ad = _ad = _createAd();
    await ad.load();
  }

  void _onButton() {
    if (_buttonText == 'Show') {
      _setButton('Load', true);
      _ad?.show();
    } else {
      _load();
    }
  }

  _FullscreenAd _createAd() {
    final formats = item.adFormats;
    if (item.integration == DemoIntegration.original) {
      return _OriginalFullscreenAd(
        item: item,
        configId: config.configId,
        rewarded: _isRewarded,
        onLoaded: _onLoaded,
        onFailed: _onFailed,
      );
    }
    if (_isRewarded) {
      final listener = PrebidRewardedAdListener(
        onAdLoaded: _onLoaded,
        onAdFailed: _onFailed,
        onAdDisplayed: () => events.fire(displayed),
        onAdClicked: () => events.fire(clicked),
        onAdClosed: () => events.fire(closed),
        onUserEarnedReward: (r) =>
            events.fire(rewarded, '${r.count} ${r.type}'),
        onAdExpired: _onExpired,
      );
      if (item.integration == DemoIntegration.gam) {
        final ad = PrebidGamRewardedAd(
          configId: config.configId,
          gamAdUnitId: item.adUnitId ?? '',
          controls: _controls,
          listener: listener,
        );
        return _FullscreenAd(ad.loadAd, ad.show, ad.destroy);
      }
      final ad = PrebidRewardedAd(
        configId: config.configId,
        controls: _controls,
        listener: listener,
      );
      return _FullscreenAd(ad.loadAd, ad.show, ad.destroy);
    }
    final listener = PrebidInterstitialAdListener(
      onAdLoaded: _onLoaded,
      onAdFailed: _onFailed,
      onAdDisplayed: () => events.fire(displayed),
      onAdClicked: () => events.fire(clicked),
      onAdClosed: () => events.fire(closed),
      onAdExpired: _onExpired,
    );
    if (item.integration == DemoIntegration.gam) {
      final ad = PrebidGamInterstitialAd(
        configId: config.configId,
        gamAdUnitId: item.adUnitId ?? '',
        adFormats: formats,
        videoParameters: item.videoParameters,
        controls: _controls,
        listener: listener,
      );
      return _FullscreenAd(ad.loadAd, ad.show, ad.destroy);
    }
    final ad = PrebidInterstitialAd(
      configId: config.configId,
      adFormats: formats,
      videoParameters: item.videoParameters,
      controls: _controls,
      listener: listener,
    );
    return _FullscreenAd(ad.loadAd, ad.show, ad.destroy);
  }

  void _onExpired() {
    events.fire(expired);
    _setButton('Load', true);
  }

  @override
  void destroyAd() => _ad?.destroy();

  @override
  Widget buildDemo(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (item.showsAdUnitLabel) ...[
          AdUnitIdLabel(config.configId),
          const SizedBox(height: 12),
        ],
        DemoButton(
          _buttonText,
          onPressed: _buttonEnabled && !_memoryLeak ? _onButton : null,
        ),
        const SizedBox(height: 16),
        EventCounterList(counters: events),
      ],
    );
  }
}

/// load / show / destroy of any fullscreen ad.
class _FullscreenAd {
  final Future<void> Function() load;
  final Future<void> Function() show;
  final Future<void> Function() destroy;

  const _FullscreenAd(this.load, this.show, this.destroy);
}

/// GAM Original fullscreen: the Prebid auction, then a Google Ad Manager
/// interstitial or rewarded ad with the winning keywords.
///
/// - interstitials: `InterstitialAdUnit` ({BANNER} or {VIDEO}, or a random
///   banner/video config with both formats), min size 30 %;
/// - rewarded: `RewardedVideoAdUnit`, or the multiformat rewarded request.
class _OriginalFullscreenAd extends _FullscreenAd {
  _OriginalFullscreenAd._(super.load, super.show, super.destroy);

  factory _OriginalFullscreenAd({
    required DemoItem item,
    required String configId,
    required bool rewarded,
    required VoidCallback onLoaded,
    required void Function(String) onFailed,
  }) {
    PrebidMultiformatAd? unit;
    gma.AdManagerInterstitialAd? interstitial;
    gma.RewardedAd? rewardedAd;
    final formats =
        item.adFormats ??
        (rewarded ? const {AdFormat.video} : const {AdFormat.banner});

    Future<void> load() async {
      unit = PrebidMultiformatAd(
        configId: configId,
        isInterstitial: !rewarded,
        isRewarded: rewarded,
        bannerSizes: formats.contains(AdFormat.banner)
            ? const [Size(320, 480)]
            : null,
        videoParameters: formats.contains(AdFormat.video)
            ? (item.videoParameters ?? kMp4Video)
            : null,
      );
      final response = await unit!.fetchDemand();
      final request = gma.AdManagerAdRequest(
        customTargeting: response.targetingKeywords ?? {},
      );
      final adUnitId = item.adUnitId ?? '';
      if (rewarded) {
        await gma.RewardedAd.loadWithAdManagerAdRequest(
          adUnitId: adUnitId,
          adManagerRequest: request,
          rewardedAdLoadCallback: gma.RewardedAdLoadCallback(
            onAdLoaded: (ad) {
              rewardedAd = ad;
              onLoaded();
            },
            onAdFailedToLoad: (e) => onFailed(e.message),
          ),
        );
      } else {
        await gma.AdManagerInterstitialAd.load(
          adUnitId: adUnitId,
          request: request,
          adLoadCallback: gma.AdManagerInterstitialAdLoadCallback(
            onAdLoaded: (ad) {
              interstitial = ad;
              onLoaded();
            },
            onAdFailedToLoad: (e) => onFailed(e.message),
          ),
        );
      }
    }

    Future<void> show() async {
      await interstitial?.show();
      await rewardedAd?.show(onUserEarnedReward: (_, _) {});
    }

    Future<void> destroy() async {
      await unit?.destroy();
      await interstitial?.dispose();
      await rewardedAd?.dispose();
    }

    return _OriginalFullscreenAd._(load, show, destroy);
  }
}
