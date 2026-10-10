import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import '../../../platform/pending_api.dart';
import '../../demo_screen.dart';
import '../shared/native_request.dart';

bool _isMax(DemoItem item) => item.integration == DemoIntegration.max;

/// G1 (AdMob banner) and H1 (MAX banner): ad · label · events · **Load** ·
/// **Stop refresh**. Refresh 30 s; Load resets only the Failed / Clicked rows.
class MediationBannerScreen extends DemoScreen {
  const MediationBannerScreen({super.key, required super.item});

  @override
  State<MediationBannerScreen> createState() => _MediationBannerScreenState();
}

class _MediationBannerScreenState
    extends DemoScreenState<MediationBannerScreen> {
  // G1 (GMA AdListener names) / H1 (MAX MaxAdViewAdListener names).
  static const _adMobRows = [
    'onAdLoaded',
    'onAdImpression',
    'onAdClicked',
    'onAdOpened',
    'onAdClosed',
    'onAdFailed',
  ];
  static const _maxRows = [
    'onAdLoaded',
    'onAdClicked called',
    'onAdLoadFailed called',
    'onAdDisplayFailed called',
    'onAdExpanded called',
    'onAdCollapsed called',
  ];

  bool get _max => _isMax(item);
  String get _clickedRow => _max ? 'onAdClicked called' : 'onAdClicked';
  String get _failedRow => _max ? 'onAdLoadFailed called' : 'onAdFailed';

  late final events = EventCounters(
    _max ? _maxRows : _adMobRows,
    tag: _max ? 'MAX banner' : 'AdMob banner',
  );
  final _controller = PrebidBannerAdController();
  int _generation = 0;

  @override
  Future<void> startAd() async {}

  void _load() {
    events.reset(only: [_failedRow, _clickedRow]);
    setState(() => _generation++);
  }

  void _stopRefresh() => _controller.stopRefresh();

  PrebidBannerAdListener get _listener => PrebidBannerAdListener(
    onAdLoaded: () => events.fire('onAdLoaded'),
    onAdFailed: (e) => events.fire(_failedRow, e),
    onAdClicked: () => events.fire(_clickedRow),
    onAdImpression: _max ? null : () => events.fire('onAdImpression'),
    onAdDisplayed: _max ? null : () => events.fire('onAdOpened'),
    onAdClosed: _max ? null : () => events.fire('onAdClosed'),
  );

  Widget _ad() {
    final refresh = config.refreshSeconds > 0 ? config.refreshSeconds : null;
    final adaptive = item.has(DemoFlag.adaptiveBanner);
    final key = ValueKey(_generation);
    if (_max) {
      return PendingApi.maxBanner(
        key: key,
        configId: config.configId,
        maxAdUnitId: item.adUnitId ?? '',
        width: config.width,
        height: config.height,
        controller: _controller,
        listener: _listener,
        refreshIntervalSeconds: refresh,
        adaptive: adaptive,
        additionalSizes: item.additionalSizes,
        onAdExpanded: () => events.fire('onAdExpanded called'),
        onAdCollapsed: () => events.fire('onAdCollapsed called'),
        onAdDisplayFailed: (e) => events.fire('onAdDisplayFailed called', e),
      );
    }
    return PendingApi.adMobBanner(
      key: key,
      configId: config.configId,
      adMobAdUnitId: item.adUnitId ?? '',
      width: config.width,
      height: config.height,
      controller: _controller,
      listener: _listener,
      refreshIntervalSeconds: refresh,
      adaptive: adaptive,
      additionalSizes: item.additionalSizes,
    );
  }

  @override
  Widget buildDemo(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdContainer(child: started ? _ad() : null),
          const SizedBox(height: 16),
          if (item.showsAdUnitLabel) AdUnitIdLabel(config.configId),
          const SizedBox(height: 16),
          EventCounterList(counters: events),
          const SizedBox(height: 16),
          DemoButtonRow(
            children: [
              DemoButton('Load', onPressed: started ? _load : null),
              DemoButton(
                'Stop refresh',
                onPressed: started ? _stopRefresh : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// G2/G3 (AdMob interstitial / rewarded) and H2/H3 (MAX). One button:
/// **Load** (disabled while loading) → **Show** → **Retry** → "Loading...".
/// As in the original, a load failure doesn't re-enable it.
///
/// The original AdMob layout crosses two rows (GMA `onAdShowedFullScreenContent`
/// lights the row labelled `onAdImpression` and vice versa); here each event
/// lights its own row.
class MediationFullscreenScreen extends DemoScreen {
  const MediationFullscreenScreen({super.key, required super.item});

  @override
  State<MediationFullscreenScreen> createState() =>
      _MediationFullscreenScreenState();
}

class _MediationFullscreenScreenState
    extends DemoScreenState<MediationFullscreenScreen> {
  static const _adMobRows = [
    'onAdLoaded',
    'onAdClicked',
    'onAdImpression',
    'onAdShowedFullScreenContent',
    'onAdDismissedFullScreenContent',
    'onAdFailedToShowFullScreenContent',
    'onAdFailed',
    'onUserRewarded called',
  ];

  bool get _max => _isMax(item);
  bool get _rewarded =>
      item.screen == ScreenType.g3 || item.screen == ScreenType.h3;

  List<String> get _rows => _max
      ? [
          'onAdLoaded',
          'onAdDisplayed called',
          'onAdHidden called',
          'onAdClicked called',
          if (_rewarded) ...[
            'onRewardedVideoStarted called',
            'onRewardedVideoCompleted called',
            'onUserRewarded called',
          ],
          'onAdLoadFailed called',
          'onAdDisplayFailed called',
        ]
      : _adMobRows;

  late final events = EventCounters(
    _rows,
    tag: '${_max ? 'MAX' : 'AdMob'} ${_rewarded ? 'rewarded' : 'interstitial'}',
  );

  String get _displayedRow =>
      _max ? 'onAdDisplayed called' : 'onAdShowedFullScreenContent';
  String get _closedRow =>
      _max ? 'onAdHidden called' : 'onAdDismissedFullScreenContent';
  String get _clickedRow => _max ? 'onAdClicked called' : 'onAdClicked';
  String get _loadFailedRow => _max ? 'onAdLoadFailed called' : 'onAdFailed';
  String get _showFailedRow =>
      _max ? 'onAdDisplayFailed called' : 'onAdFailedToShowFullScreenContent';

  Future<void> Function()? _loadAd;
  Future<void> Function()? _showAd;
  Future<void> Function()? _destroy;
  String _text = 'Load';
  bool _enabled = false;
  bool _shown = false;

  @override
  Future<void> startAd() => _load();

  void _bind(
    Future<void> Function() load,
    Future<void> Function() show,
    Future<void> Function() destroy,
  ) {
    _loadAd = load;
    _showAd = show;
    _destroy = destroy;
  }

  void _set(String text, bool enabled) {
    if (mounted) {
      setState(() {
        _text = text;
        _enabled = enabled;
      });
    }
  }

  Size? get _minSize => item.size.isMinSizePercentage
      ? Size(config.width.toDouble(), config.height.toDouble())
      : item.minSizePercentage;

  Future<void> _load() async {
    await _destroy?.call();
    _shown = false;
    void loaded() {
      events.fire('onAdLoaded');
      _set('Show', true);
    }

    void failed(String e) =>
        events.fire(_shown ? _showFailedRow : _loadFailedRow, e);
    final adUnitId = item.adUnitId ?? '';

    if (_rewarded) {
      final listener = PrebidRewardedAdListener(
        onAdLoaded: loaded,
        onAdFailed: failed,
        onAdDisplayed: () => events.fire(_displayedRow),
        onAdClosed: () => events.fire(_closedRow),
        onAdClicked: () => events.fire(_clickedRow),
        onAdImpression: _max ? null : () => events.fire('onAdImpression'),
        onUserEarnedReward: (r) =>
            events.fire('onUserRewarded called', '${r.count} ${r.type}'),
      );
      if (_max) {
        final ad = PrebidMaxRewardedAd(
          configId: config.configId,
          maxAdUnitId: adUnitId,
          listener: listener,
        );
        _bind(ad.loadAd, ad.show, ad.destroy);
      } else {
        final ad = PrebidAdMobRewardedAd(
          configId: config.configId,
          adMobAdUnitId: adUnitId,
          listener: listener,
        );
        _bind(ad.loadAd, ad.show, ad.destroy);
      }
    } else {
      final listener = PrebidInterstitialAdListener(
        onAdLoaded: loaded,
        onAdFailed: failed,
        onAdDisplayed: () => events.fire(_displayedRow),
        onAdClosed: () => events.fire(_closedRow),
        onAdClicked: () => events.fire(_clickedRow),
        onAdImpression: _max ? null : () => events.fire('onAdImpression'),
      );
      final formats = item.adFormats ?? const {AdFormat.banner};
      if (_max) {
        final ad = PendingApi.maxInterstitial(
          configId: config.configId,
          maxAdUnitId: adUnitId,
          adFormats: formats,
          minSizePercentage: _minSize,
          listener: listener,
        );
        _bind(ad.loadAd, ad.show, ad.destroy);
      } else {
        final ad = PendingApi.adMobInterstitial(
          configId: config.configId,
          adMobAdUnitId: adUnitId,
          adFormats: formats,
          minSizePercentage: _minSize,
          listener: listener,
        );
        _bind(ad.loadAd, ad.show, ad.destroy);
      }
    }
    await _loadAd!();
  }

  void _onButton() {
    switch (_text) {
      case 'Show':
        _shown = true;
        _set('Retry', true);
        _showAd?.call();
      case 'Retry':
        events.reset(only: _rows);
        _set('Loading...', false);
        _load();
    }
  }

  @override
  void destroyAd() => _destroy?.call();

  @override
  Widget buildDemo(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (item.showsAdUnitLabel) ...[
          AdUnitIdLabel(config.configId),
          const SizedBox(height: 12),
        ],
        EventCounterList(counters: events),
        const SizedBox(height: 16),
        DemoButton(_text, onPressed: _enabled ? _onButton : null),
      ],
    );
  }
}

/// G4 (AdMob native) and H4 (MAX native): the ad · label · **Load**.
class MediationNativeScreen extends DemoScreen {
  const MediationNativeScreen({super.key, required super.item});

  @override
  State<MediationNativeScreen> createState() => _MediationNativeScreenState();
}

class _MediationNativeScreenState
    extends DemoScreenState<MediationNativeScreen> {
  bool get _max => _isMax(item);

  late final events = EventCounters(
    _max
        ? const [
            'onNativeAdLoaded called',
            'onNativeAdClicked called',
            'onNativeAdLoadFailed called',
            'onAdRevenuePaid called',
          ]
        : const [
            'onAdLoaded',
            'onAdImpression',
            'onAdClicked',
            'onAdOpened',
            'onAdFailed',
          ],
    tag: _max ? 'MAX native' : 'AdMob native',
  );

  int _generation = 0;
  bool _loadEnabled = false;

  @override
  Future<void> startAd() async {}

  void _load() {
    events.reset(only: events.labels);
    setState(() {
      _loadEnabled = false;
      _generation++;
    });
  }

  void _result(String row, [String? detail]) {
    events.fire(row, detail);
    if (mounted) setState(() => _loadEnabled = true);
  }

  Widget _ad() {
    final key = ValueKey(_generation);
    final adUnitId = item.adUnitId ?? '';
    if (_max) {
      return PrebidMaxNativeAd(
        key: key,
        configId: config.configId,
        maxAdUnitId: adUnitId,
        assets: kStandardNativeAssets,
        eventTrackers: kStandardNativeTrackers,
        context: kNativeContext,
        contextSubType: kNativeContextSubType,
        placementType: kNativePlacement,
        listener: PrebidMaxNativeAdListener(
          onAdLoaded: () => _result('onNativeAdLoaded called'),
          onAdFailed: (e) => _result('onNativeAdLoadFailed called', e),
          onAdClicked: () => events.fire('onNativeAdClicked called'),
          onAdRevenuePaid: (r) => events.fire(
            'onAdRevenuePaid called',
            '${r.revenue} ${r.networkName}',
          ),
        ),
      );
    }
    return PrebidAdMobNativeAd(
      key: key,
      configId: config.configId,
      adMobAdUnitId: adUnitId,
      assets: kStandardNativeAssets,
      eventTrackers: kStandardNativeTrackers,
      context: kNativeContext,
      contextSubType: kNativeContextSubType,
      placementType: kNativePlacement,
      listener: PrebidAdMobNativeAdListener(
        onAdLoaded: () => _result('onAdLoaded'),
        onAdFailed: (e) => _result('onAdFailed', e),
        onAdImpression: () => events.fire('onAdImpression'),
        onAdClicked: () => events.fire('onAdClicked'),
        onAdOpened: () => events.fire('onAdOpened'),
      ),
    );
  }

  @override
  Widget buildDemo(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (started) _ad(),
        const SizedBox(height: 16),
        if (item.showsAdUnitLabel) AdUnitIdLabel(config.configId),
        const SizedBox(height: 16),
        EventCounterList(counters: events),
        const SizedBox(height: 16),
        DemoButton('Load', onPressed: _loadEnabled ? _load : null),
      ],
    );
  }
}
