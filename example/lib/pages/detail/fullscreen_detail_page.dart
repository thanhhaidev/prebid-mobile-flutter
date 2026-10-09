import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import '../../models/demo_ad_category.dart';
import '../../models/demo_ad_format.dart';
import '../../models/demo_integration.dart';
import '../../models/test_case.dart';
import '../../utils/bid_summary.dart';
import '../../widgets/action_button.dart';
import '../../widgets/ad_unit_header.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/event_counter.dart';
import '../../widgets/fullscreen_controls_dialog.dart';

/// Interstitial and rewarded test cases — Load, then Show.
///
/// Every integration is supported:
/// - **In-App / GAM / AdMob / MAX** through the plugin's ad objects, which
///   share [PrebidInterstitialAdListener] / [PrebidRewardedAdListener] and
///   accept [PrebidFullscreenControls] (gear icon → "Configure the Ad").
/// - **GAM Original API**: Prebid's `fetchDemand` returns targeting keywords
///   that go into a `google_mobile_ads` Ad Manager interstitial / rewarded ad,
///   rendered by the Prebid Universal Creative.
class FullscreenDetailPage extends StatefulWidget {
  final TestCase tc;
  const FullscreenDetailPage({super.key, required this.tc});

  @override
  State<FullscreenDetailPage> createState() => _FullscreenDetailPageState();
}

class _FullscreenDetailPageState extends State<FullscreenDetailPage> {
  late final EventTracker _tracker = EventTracker(
    _isRewarded ? 'Rewarded' : 'Interstitial',
  );

  late String _configId = widget.tc.configId;
  PrebidFullscreenControls? _controls;
  bool _canShow = false;

  Future<void> Function()? _show;
  Future<void> Function()? _destroy;

  bool get _isRewarded =>
      widget.tc.format == DemoAdFormat.displayRewarded ||
      widget.tc.format == DemoAdFormat.videoRewarded;

  bool get _isVideo =>
      widget.tc.format == DemoAdFormat.videoInterstitial ||
      widget.tc.format == DemoAdFormat.videoRewarded;

  DemoIntegration get _integration => widget.tc.integration;

  String get _adUnitId => widget.tc.adUnitId ?? '';

  /// Callback rows for this integration, matching the reference test app.
  List<String> get _events => [
    if (_integration == DemoIntegration.original) ...[
      'fetchDemand success',
      'fetchDemand failed',
    ],
    'onAdLoaded',
    'onAdFailed',
    'onAdDisplayed',
    if (_integration != DemoIntegration.inApp &&
        _integration != DemoIntegration.gam)
      'onAdImpression',
    'onAdClicked',
    'onAdClosed',
    if (_isRewarded) 'onUserEarnedReward',
    if (_integration == DemoIntegration.inApp ||
        _integration == DemoIntegration.gam)
      'onAdExpired',
  ];

  void _onLoaded() {
    _tracker.track('onAdLoaded');
    if (mounted) setState(() => _canShow = true);
  }

  void _onClosed() {
    _tracker.track('onAdClosed');
    if (mounted) setState(() => _canShow = false);
  }

  PrebidInterstitialAdListener _interstitialListener() =>
      PrebidInterstitialAdListener(
        onAdLoaded: _onLoaded,
        onAdFailed: (e) => _tracker.track('onAdFailed', e),
        onAdDisplayed: () => _tracker.track('onAdDisplayed'),
        onAdImpression: () => _tracker.track('onAdImpression'),
        onAdClicked: () => _tracker.track('onAdClicked'),
        onAdClosed: _onClosed,
        onAdExpired: () => _tracker.track('onAdExpired'),
      );

  PrebidRewardedAdListener _rewardedListener() => PrebidRewardedAdListener(
    onAdLoaded: _onLoaded,
    onAdFailed: (e) => _tracker.track('onAdFailed', e),
    onAdDisplayed: () => _tracker.track('onAdDisplayed'),
    onAdImpression: () => _tracker.track('onAdImpression'),
    onAdClicked: () => _tracker.track('onAdClicked'),
    onAdClosed: _onClosed,
    onUserEarnedReward: (r) => _tracker.track(
      'onUserEarnedReward',
      '${r.count ?? '-'} ${r.type ?? ''}${r.ext == null ? '' : ' ext=${r.ext}'}',
    ),
    onAdExpired: () => _tracker.track('onAdExpired'),
  );

  Future<void> _load() async {
    await _destroy?.call();
    _show = null;
    _destroy = null;
    _tracker.reset();
    setState(() => _canShow = false);
    await PrebidMobile.clearStoredAuctionResponse();
    _tracker.track(
      'load',
      '${_integration.label} $_configId${_controls == null ? '' : ' +controls'}',
    );

    if (_integration == DemoIntegration.original) {
      await _loadOriginal();
      return;
    }

    final formats = {_isVideo ? AdFormat.video : AdFormat.banner};
    if (_isRewarded) {
      final listener = _rewardedListener();
      switch (_integration) {
        case DemoIntegration.inApp:
          final ad = PrebidRewardedAd(
            configId: _configId,
            controls: _controls,
            listener: listener,
          );
          _bind(ad.show, ad.destroy);
          await ad.loadAd();
        case DemoIntegration.gam:
          final ad = PrebidGamRewardedAd(
            configId: _configId,
            gamAdUnitId: _adUnitId,
            controls: _controls,
            listener: listener,
          );
          _bind(ad.show, ad.destroy);
          await ad.loadAd();
        case DemoIntegration.admob:
          final ad = PrebidAdMobRewardedAd(
            configId: _configId,
            adMobAdUnitId: _adUnitId,
            controls: _controls,
            listener: listener,
          );
          _bind(ad.show, ad.destroy);
          await ad.loadAd();
        case DemoIntegration.max:
          final ad = PrebidMaxRewardedAd(
            configId: _configId,
            maxAdUnitId: _adUnitId,
            controls: _controls,
            listener: listener,
          );
          _bind(ad.show, ad.destroy);
          await ad.loadAd();
        case DemoIntegration.original:
          break;
      }
      return;
    }

    final listener = _interstitialListener();
    switch (_integration) {
      case DemoIntegration.inApp:
        final ad = PrebidInterstitialAd(
          configId: _configId,
          adFormats: formats,
          controls: _controls,
          listener: listener,
        );
        _bind(ad.show, ad.destroy);
        await ad.loadAd();
      case DemoIntegration.gam:
        final ad = PrebidGamInterstitialAd(
          configId: _configId,
          gamAdUnitId: _adUnitId,
          adFormats: formats,
          controls: _controls,
          listener: listener,
        );
        _bind(ad.show, ad.destroy);
        await ad.loadAd();
      case DemoIntegration.admob:
        final ad = PrebidAdMobInterstitialAd(
          configId: _configId,
          adMobAdUnitId: _adUnitId,
          isVideo: _isVideo,
          controls: _controls,
          listener: listener,
        );
        _bind(ad.show, ad.destroy);
        await ad.loadAd();
      case DemoIntegration.max:
        final ad = PrebidMaxInterstitialAd(
          configId: _configId,
          maxAdUnitId: _adUnitId,
          isVideo: _isVideo,
          controls: _controls,
          listener: listener,
        );
        _bind(ad.show, ad.destroy);
        await ad.loadAd();
      case DemoIntegration.original:
        break;
    }
  }

  void _bind(Future<void> Function() show, Future<void> Function() destroy) {
    _show = show;
    _destroy = destroy;
  }

  // ---- GAM Original API ----------------------------------------------------

  /// Prebid `fetchDemand` → targeting keywords → Ad Manager fullscreen ad.
  Future<void> _loadOriginal() async {
    final video = _isVideo || _isRewarded;
    final adUnit = PrebidMultiformatAd(
      configId: _configId,
      bannerSizes: video ? null : const [Size(320, 480)],
      videoParameters: video
          ? const VideoParameters(
              mimes: ['video/mp4'],
              protocols: [VideoProtocol.vast2_0],
              playbackMethods: [VideoPlaybackMethod.autoPlaySoundOff],
              placement: VideoPlacement.interstitial,
            )
          : null,
      isInterstitial: true,
      isRewarded: _isRewarded,
    );
    _destroy = adUnit.destroy;

    final result = await adUnit.fetchDemand();
    if (result.isSuccess) {
      _tracker.track('fetchDemand success', bidSummary(result));
    } else {
      _tracker.track('fetchDemand failed', result.resultCode);
    }
    final request = gma.AdManagerAdRequest(
      customTargeting: result.targetingKeywords ?? const {},
    );

    if (_isRewarded) {
      await gma.RewardedAd.loadWithAdManagerAdRequest(
        adUnitId: _adUnitId,
        adManagerRequest: request,
        rewardedAdLoadCallback: gma.RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = _gmaCallback();
            _show = () async => ad.show(
              onUserEarnedReward: (_, reward) => _tracker.track(
                'onUserEarnedReward',
                '${reward.amount} ${reward.type}',
              ),
            );
            _destroy = () async {
              await ad.dispose();
              await adUnit.destroy();
            };
            _onLoaded();
          },
          onAdFailedToLoad: (e) => _tracker.track('onAdFailed', e.message),
        ),
      );
    } else {
      await gma.AdManagerInterstitialAd.load(
        adUnitId: _adUnitId,
        request: request,
        adLoadCallback: gma.AdManagerInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = _gmaCallback();
            _show = ad.show;
            _destroy = () async {
              await ad.dispose();
              await adUnit.destroy();
            };
            _onLoaded();
          },
          onAdFailedToLoad: (e) => _tracker.track('onAdFailed', e.message),
        ),
      );
    }
  }

  gma.FullScreenContentCallback<T> _gmaCallback<T extends gma.Ad>() =>
      gma.FullScreenContentCallback<T>(
        onAdShowedFullScreenContent: (_) => _tracker.track('onAdDisplayed'),
        onAdImpression: (_) => _tracker.track('onAdImpression'),
        onAdClicked: (_) => _tracker.track('onAdClicked'),
        onAdDismissedFullScreenContent: (_) => _onClosed(),
        onAdFailedToShowFullScreenContent: (_, e) =>
            _tracker.track('onAdFailed', e.message),
      );

  // ---------------------------------------------------------------------------

  Future<void> _configure() async {
    final cfg = await FullscreenControlsDialog.show(
      context,
      initial: FullscreenConfig(configId: _configId, controls: _controls),
      isRewarded: _isRewarded,
    );
    if (cfg == null) return;
    setState(() {
      _configId = cfg.configId;
      _controls = cfg.controls;
    });
    await _load();
  }

  @override
  void dispose() {
    _destroy?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supportsControls = _integration != DemoIntegration.original;
    return AdDetailScaffold(
      title: widget.tc.title,
      tracker: _tracker,
      events: _events,
      onConfigure: supportsControls ? _configure : null,
      header: AdUnitHeader(
        configId: _configId,
        category: categoryOf(widget.tc),
        integration: _integration,
        adUnitId: widget.tc.adUnitId,
      ),
      actions: [
        ActionButton(
          label: 'Load',
          icon: Icons.download_rounded,
          onPressed: _load,
        ),
        ActionButton(
          label: 'Show',
          primary: false,
          icon: Icons.open_in_full_rounded,
          onPressed: _canShow ? () => _show?.call() : null,
        ),
      ],
    );
  }
}
