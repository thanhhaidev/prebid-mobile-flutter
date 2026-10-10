import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';

import '../../../pages/examples_page.dart' show kAppTitle;
import '../../../theme/app_theme.dart';
import '../../demo_screen.dart';

const _loaded = 'onAdLoaded called';
const _displayed = 'onAdDisplayed called';
const _failed = 'onAdFailed called';

/// A3 — "Banner 320x50 Scrollable Reusable (In-App)" (`PpmBannerReusableFragment`).
///
/// The original creates one `BannerView`, loads it with **Load ad**, attaches
/// it to the container with **Add** and detaches it with **Remove**; it does
/// not auto-load. A Flutter platform view can't be re-parented, so the banner
/// is built on Load ad and shown / hidden in place ([Offstage] keeps the
/// loaded view alive while removed).
class ReusableBannerScreen extends DemoScreen {
  const ReusableBannerScreen({super.key, required super.item});

  @override
  State<ReusableBannerScreen> createState() => _ReusableBannerScreenState();
}

class _ReusableBannerScreenState extends DemoScreenState<ReusableBannerScreen> {
  late final events = EventCounters([_loaded, _displayed, _failed]);
  bool _created = false;
  bool _attached = false;

  @override
  Future<void> startAd() async {} // No auto-load.

  PrebidBannerAdListener get _listener => PrebidBannerAdListener(
    onAdLoaded: () => events.fire(_loaded),
    onAdDisplayed: () => events.fire(_displayed),
    onAdFailed: (e) => events.fire(_failed, e),
  );

  @override
  Widget buildDemo(BuildContext context) {
    final c = DemoColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (item.showsAdUnitLabel) AdUnitIdLabel(config.configId),
        const SizedBox(height: 12),
        DemoButtonRow(
          children: [
            DemoButton(
              'Load ad',
              onPressed: _created
                  ? null
                  : () => setState(() => _created = true),
            ),
            DemoButton(
              'Add',
              onPressed: _created && !_attached
                  ? () => setState(() => _attached = true)
                  : null,
            ),
            DemoButton(
              'Remove',
              onPressed: _attached
                  ? () => setState(() => _attached = false)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        EventCounterList(counters: events),
        const SizedBox(height: 16),
        Container(height: 300, color: c.surface),
        Center(
          child: SizedBox(
            width: config.width.toDouble(),
            height: _attached ? config.height.toDouble() : 0,
            child: _created
                ? Offstage(
                    offstage: !_attached,
                    child: PrebidBannerAd(
                      configId: config.configId,
                      width: config.width,
                      height: config.height,
                      listener: _listener,
                    ),
                  )
                : null,
          ),
        ),
        Container(height: 300, color: c.surface),
      ],
    );
  }
}

/// A4 — "Banner 320x50 Recycler view (In-App)" (`PpmBannerRecyclerViewFragment`).
///
/// Rows: 3 grey placeholders (500 dp), a banner row, 6 placeholders, a banner
/// row, 1 placeholder. The original moves ONE shared `BannerView` between the
/// banner rows; platform views can't be moved, so each banner row hosts its
/// own banner (refresh 30 s).
class RecyclerBannerScreen extends DemoScreen {
  const RecyclerBannerScreen({super.key, required super.item});

  @override
  State<RecyclerBannerScreen> createState() => _RecyclerBannerScreenState();
}

class _RecyclerBannerScreenState extends DemoScreenState<RecyclerBannerScreen> {
  late final events = EventCounters([_loaded, _displayed, _failed]);

  static const _rows = [
    false, false, false, true, false, false, false, false, false, false, //
    true, false,
  ];

  @override
  Future<void> startAd() async {}

  @override
  Widget buildDemo(BuildContext context) {
    final c = DemoColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (item.showsAdUnitLabel) AdUnitIdLabel(config.configId),
              const SizedBox(height: 12),
              EventCounterList(counters: events),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _rows.length,
            itemBuilder: (context, i) => _rows[i]
                ? Center(
                    child: started
                        ? PrebidBannerAd(
                            configId: config.configId,
                            width: config.width,
                            height: config.height,
                            refreshIntervalSeconds: 30,
                            listener: PrebidBannerAdListener(
                              onAdLoaded: () => events.fire(_loaded),
                              onAdDisplayed: () => events.fire(_displayed),
                              onAdFailed: (e) => events.fire(_failed, e),
                            ),
                          )
                        : SizedBox(height: config.height.toDouble()),
                  )
                : Container(
                    height: 500,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: c.surface,
                  ),
          ),
        ),
      ],
    );
  }
}

/// E — "Banners and Interstitial" (In-App and GAM):
/// `PpmBannersWithInterstitialFragment` / `GamBannersAndInterstitialFragment`.
///
/// A top banner (refresh 15 s) and a bottom banner (refresh 60 s) of
/// `prebid-demo-banner-320-50`, each with an info button
/// (`Config ID: X\nRefresh Interval: N sec\nImpressions Count: K`, K = its
/// onAdLoaded count), and an interstitial of
/// `prebid-demo-display-interstitial-320-480` (min size 30 %) behind a
/// "Loading…" → "Show" button; it reloads after closing.
class BannersAndInterstitialScreen extends DemoScreen {
  const BannersAndInterstitialScreen({super.key, required super.item});

  @override
  State<BannersAndInterstitialScreen> createState() =>
      _BannersAndInterstitialScreenState();
}

class _BannersAndInterstitialScreenState
    extends DemoScreenState<BannersAndInterstitialScreen> {
  static const _bannerConfig = 'prebid-demo-banner-320-50';
  static const _interstitialConfig = 'prebid-demo-display-interstitial-320-480';
  static const _gamBannerUnit = '/21808260008/prebid_oxb_320x50_banner';
  static const _gamInterstitialUnit =
      '/21808260008/prebid_oxb_html_interstitial';

  int _topImpressions = 0;
  int _bottomImpressions = 0;
  bool _interstitialReady = false;
  _Interstitial? _interstitial;

  bool get _gam => item.integration == DemoIntegration.gam;

  @override
  Future<void> startAd() async => _loadInterstitial();

  void _loadInterstitial() {
    _interstitial?.destroy();
    final listener = PrebidInterstitialAdListener(
      onAdLoaded: () => setState(() => _interstitialReady = true),
      onAdClosed: _loadInterstitial,
    );
    const controls = PrebidFullscreenControls(minSizePercentage: Size(30, 30));
    _interstitial = _gam
        ? _Interstitial.gam(
            PrebidGamInterstitialAd(
              configId: _interstitialConfig,
              gamAdUnitId: _gamInterstitialUnit,
              controls: controls,
              listener: listener,
            ),
          )
        : _Interstitial.inApp(
            PrebidInterstitialAd(
              configId: _interstitialConfig,
              controls: controls,
              listener: listener,
            ),
          );
    if (mounted) setState(() => _interstitialReady = false);
    _interstitial!.load();
  }

  @override
  void destroyAd() => _interstitial?.destroy();

  Widget _banner(int refresh, VoidCallback onLoaded) {
    final listener = PrebidBannerAdListener(onAdLoaded: onLoaded);
    return _gam
        ? PrebidGamBannerAd(
            configId: _bannerConfig,
            gamAdUnitId: _gamBannerUnit,
            width: 320,
            height: 50,
            refreshIntervalSeconds: refresh,
            listener: listener,
          )
        : PrebidBannerAd(
            configId: _bannerConfig,
            width: 320,
            height: 50,
            refreshIntervalSeconds: refresh,
            listener: listener,
          );
  }

  Widget _info(int refresh, int impressions) => OutlinedButton(
    onPressed: () {},
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Config ID: $_bannerConfig\nRefresh Interval: $refresh sec\n'
        'Impressions Count: $impressions',
        textAlign: TextAlign.center,
        style: AppFonts.monoStyle(fontSize: 12.5),
      ),
    ),
  );

  @override
  Widget buildDemo(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdContainer(
          child: started
              ? _banner(15, () => setState(() => _topImpressions++))
              : null,
        ),
        const SizedBox(height: 8),
        _info(15, _topImpressions),
        const SizedBox(height: 24),
        AdContainer(
          child: started
              ? _banner(60, () => setState(() => _bottomImpressions++))
              : null,
        ),
        const SizedBox(height: 8),
        _info(60, _bottomImpressions),
        const SizedBox(height: 24),
        DemoButton(
          _interstitialReady ? 'Show' : 'Loading…',
          onPressed: _interstitialReady
              ? () {
                  setState(() => _interstitialReady = false);
                  _interstitial?.show();
                }
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          'Interstitial Config ID: $_interstitialConfig',
          textAlign: TextAlign.center,
          style: AppFonts.monoStyle(fontSize: 12.5),
        ),
      ],
    );
  }
}

/// In-App or GAM interstitial behind one interface.
class _Interstitial {
  _Interstitial._(this.load, this.show, this.destroy);

  factory _Interstitial.inApp(PrebidInterstitialAd ad) =>
      _Interstitial._(ad.loadAd, ad.show, ad.destroy);

  factory _Interstitial.gam(PrebidGamInterstitialAd ad) =>
      _Interstitial._(ad.loadAd, ad.show, ad.destroy);
  final Future<void> Function() load;
  final Future<void> Function() show;
  final Future<void> Function() destroy;
}

/// F — video outstream feeds (In-App `PpmFeedVideoFragment`, GAM
/// `GamOustreamFeedFragment`): an endless list of text rows with an in-feed
/// video banner (300x250) at every position where `pos % 5 == 0 && pos != 0`.
/// The original reloads one shared view at each ad row; here each ad row
/// hosts its own banner.
class VideoFeedScreen extends DemoScreen {
  const VideoFeedScreen({super.key, required super.item});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends DemoScreenState<VideoFeedScreen> {
  @override
  Future<void> startAd() async {}

  Widget _ad() => item.integration == DemoIntegration.gam
      ? PrebidGamBannerAd(
          configId: config.configId,
          gamAdUnitId: item.adUnitId ?? '',
          width: config.width,
          height: config.height,
          adFormats: const {PrebidAdFormat.video},
          videoPlacementType: VideoPlacementType.inFeed,
        )
      : PrebidBannerAd(
          configId: config.configId,
          width: config.width,
          height: config.height,
          adFormats: const {PrebidAdFormat.video},
          videoPlacementType: VideoPlacementType.inFeed,
        );

  @override
  Widget buildDemo(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, pos) {
        if (pos % 5 == 0 && pos != 0 && started) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(child: _ad()),
          );
        }
        return const ListTile(title: Text(kAppTitle));
      },
    );
  }
}
