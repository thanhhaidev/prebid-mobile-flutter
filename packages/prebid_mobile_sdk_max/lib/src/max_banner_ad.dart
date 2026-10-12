import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/companion.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show
        PrebidAdFormat,
        PrebidAdPosition,
        PrebidBannerAdController,
        PrebidBannerAdListener,
        VideoParameters;

import 'max_listeners.dart';
import 'max_testing.dart';

/// A banner ad mediated by **AppLovin MAX** with Prebid demand.
///
/// Prebid runs the auction via a `MediationBannerAdUnit` and passes the winning
/// bid to MAX through the Prebid MAX adapter; MAX then renders either the Prebid
/// creative or a competing MAX creative. Contrast with the core
/// `PrebidBannerAd`, where the Prebid SDK renders directly.
class PrebidMaxBannerAd extends StatefulWidget {
  /// Creates a [PrebidMaxBannerAd] widget.
  const PrebidMaxBannerAd({
    super.key,
    required this.configId,
    required this.maxAdUnitId,
    required this.width,
    required this.height,
    this.additionalSizes,
    this.adaptive = false,
    this.adFormats,
    this.videoParameters,
    this.refreshIntervalSeconds,
    this.autoLoad = true,
    this.controller,
    this.adPosition,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.pbAdSlot,
    this.gpid,
    this.listener,
  });

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AppLovin MAX ad unit ID.
  final String maxAdUnitId;

  /// The desired width of the banner ad in dp.
  final int width;

  /// The desired height of the banner ad in dp.
  final int height;

  /// Further sizes Prebid may bid on besides [width] x [height] (e.g.
  /// `[Size(728, 90)]`), sent in the Prebid request
  /// (`MediationBannerAdUnit.addAdditionalSize` / `additionalSizes`). The MAX
  /// view keeps its own size — [adaptive] or [width] x [height].
  final List<Size>? additionalSizes;

  /// Whether the MAX view is an **adaptive banner** (MAX extra parameter
  /// `adaptive_banner` = `true`) spanning the full width available to the
  /// widget, at the height MAX computes for that width, instead of a fixed
  /// [width] x [height]. [width] x [height] (plus [additionalSizes]) remain
  /// the Prebid request sizes. The width is measured once, at the first
  /// layout. Ignored for a 300x250 (MREC) banner.
  final bool adaptive;

  /// Formats Prebid bids on for this slot — e.g. `{PrebidAdFormat.video}` for
  /// an outstream video banner or `{PrebidAdFormat.banner,
  /// PrebidAdFormat.video}` for a multiformat one (the winning bid decides
  /// the creative, which MAX renders through the Prebid adapter). `null` or
  /// empty keeps Prebid's default, a display banner
  /// (`MediationBannerAdUnit.setAdUnitFormats` / `adFormats`).
  final Set<PrebidAdFormat>? adFormats;

  /// Video signals for a video or multiformat banner (see [adFormats]). iOS
  /// only: Prebid Android's `MediationBannerAdUnit` has no video-parameters
  /// setter, so Android sends the SDK's defaults.
  final VideoParameters? videoParameters;

  /// Prebid auto-refresh interval in seconds; each refresh runs a new auction
  /// and reloads the MAX view. `null` (default) or `0` disables Prebid's
  /// auto-refresh on both platforms; positive values are clamped by Prebid to
  /// its supported range (Android 30–120 s, iOS 15–120 s). MAX's own banner
  /// refresh (set in the MAX dashboard) is separate. Stop both at runtime
  /// with [PrebidBannerAdController.stopRefresh].
  final int? refreshIntervalSeconds;

  /// Whether the ad should load automatically when the widget is created. Set
  /// to `false` and call [PrebidBannerAdController.loadAd] on [controller] to
  /// load on demand.
  final bool autoLoad;

  /// Optional controller to load on demand (`autoLoad: false`) or stop
  /// Prebid's (and the ad server's) auto-refresh.
  final PrebidBannerAdController? controller;

  /// Ad position on screen (`imp.banner.pos`).
  final PrebidAdPosition? adPosition;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp` (also
  /// how to set the GPID: `{"ext":{"gpid":"/1111/home"}}`).
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only (merged over
  /// `PrebidTargeting.setGlobalOrtbConfig`).
  final String? globalOrtbConfig;

  /// Prebid ad slot (`imp.ext.data.pbadslot`). Prebid iOS has no setter on
  /// this ad unit, so on iOS it is added to [impOrtbConfig] (a `pbadslot`
  /// already there wins).
  final String? pbAdSlot;

  /// Global Placement ID (`imp.ext.gpid`), e.g. `/1111/home`. Sent in
  /// [impOrtbConfig]; a `gpid` already there wins.
  final String? gpid;

  /// Listener for banner ad events. Pass a [PrebidMaxBannerAdListener] to
  /// also get MAX's expand / collapse, display-failure and revenue events.
  final PrebidBannerAdListener? listener;

  @override
  State<PrebidMaxBannerAd> createState() => _PrebidMaxBannerAdState();
}

class _PrebidMaxBannerAdState extends State<PrebidMaxBannerAd>
    with AdViewState<PrebidMaxBannerAd> {
  /// [PrebidMax.debugDropBidProbability] as read when the view was created.
  Map<String, Object> _debugArgs = debugDropBidArgs();

  @override
  String get viewType => 'prebid_mobile_sdk_max/banner';

  @override
  PrebidBannerAdController? controllerOf(PrebidMaxBannerAd widget) =>
      widget.controller;

  @override
  bool autoLoadOf(PrebidMaxBannerAd widget) => widget.autoLoad;

  @override
  void onViewReplaced() => _debugArgs = debugDropBidArgs();

  @override
  Map<String, Object?> configOf(PrebidMaxBannerAd widget) => _maxBannerConfig(
    configId: widget.configId,
    maxAdUnitId: widget.maxAdUnitId,
    width: widget.width,
    height: widget.height,
    autoLoad: widget.autoLoad,
    adaptive: widget.adaptive,
    adPosition: widget.adPosition,
    impOrtbConfig: impOrtbWithGpid(widget.impOrtbConfig, widget.gpid),
    globalOrtbConfig: widget.globalOrtbConfig,
    pbAdSlot: widget.pbAdSlot,
    additionalSizes: widget.additionalSizes,
    adFormats: widget.adFormats,
    videoParameters: widget.videoParameters,
    refreshIntervalSeconds: widget.refreshIntervalSeconds,
  );

  /// MREC banners keep their fixed size: MAX adaptive banners are banner-only.
  bool get _isAdaptive =>
      widget.adaptive && !(widget.width == 300 && widget.height == 250);

  /// The slot starts at the requested size (an adaptive one at the available
  /// width) and adopts the rendered creative's size once the native SDK
  /// reports it.
  @override
  Widget build(BuildContext context) {
    if (!_isAdaptive) {
      return SizedBox(
        width: reportedWidth ?? widget.width.toDouble(),
        height: reportedHeight ?? widget.height.toDouble(),
        child: buildAdView(extraParams: _debugArgs),
      );
    }
    return buildAdaptive(
      (width) => SizedBox(
        width: width,
        height: reportedHeight ?? widget.height.toDouble(),
        child: buildAdView(
          extraParams: {'adaptiveWidth': width.round(), ..._debugArgs},
        ),
      ),
    );
  }

  @override
  void onViewEvent(MethodCall call) =>
      _dispatchMaxBannerEvent(widget.listener, call);
}

/// Calls [listener] for a MAX banner view [event]: the banner events, and
/// MAX's own when it is a [PrebidMaxBannerAdListener].
void _dispatchMaxBannerEvent(
  PrebidBannerAdListener? listener,
  MethodCall event,
) {
  if (dispatchBannerEvent(listener, null, event)) return;
  final max = listener is PrebidMaxBannerAdListener ? listener : null;
  switch (event.method) {
    case 'onAdDisplayFailed':
      // The specific callback first, so a listener can tell this
      // onAdFailed from a load failure.
      final error = adEventError(event.arguments);
      max?.onAdDisplayFailed?.call(error);
      listener?.onAdFailed?.call(error);
    case 'onAdExpanded':
      max?.onAdExpanded?.call();
    case 'onAdCollapsed':
      max?.onAdCollapsed?.call();
    case 'onAdRevenuePaid':
      max?.onAdRevenuePaid?.call(maxAdRevenueFrom(event.arguments as Map?));
  }
}

/// The creation params of a native MAX banner, for [PrebidMaxBannerAd] and
/// [PrebidMaxPreloadedBannerAd].
Map<String, Object?> _maxBannerConfig({
  required String configId,
  required String maxAdUnitId,
  required int width,
  required int height,
  required bool autoLoad,
  required bool adaptive,
  PrebidAdPosition? adPosition,
  String? impOrtbConfig,
  String? globalOrtbConfig,
  String? pbAdSlot,
  List<Size>? additionalSizes,
  Set<PrebidAdFormat>? adFormats,
  VideoParameters? videoParameters,
  int? refreshIntervalSeconds,
}) => {
  'configId': configId,
  'maxAdUnitId': maxAdUnitId,
  'width': width,
  'height': height,
  'autoLoad': autoLoad,
  'adPosition': ?adPosition?.value,
  'impOrtbConfig': ?impOrtbConfig,
  'globalOrtbConfig': ?globalOrtbConfig,
  'pbAdSlot': ?pbAdSlot,
  if (additionalSizes case final sizes?) 'additionalSizes': flatSizes(sizes),
  if (adaptive) 'adaptive': true,
  'adFormats': ?adFormats?.map((f) => f.name).toList(),
  'videoParameters': ?videoParameters?.toMap(),
  'refreshIntervalSeconds': ?refreshIntervalSeconds,
};

/// A [PrebidMaxBannerAd] loaded before its slot is on screen and kept
/// across the views showing it: [load] it, show it with a
/// [PrebidMaxPreloadedBannerAdView], and [destroy] it when you no longer
/// need it. In a scrolling list, a slot scrolled away and back shows the
/// same ad instead of running a new auction.
///
/// The banner shows in one view at a time: a view built later takes it over
/// from the one showing it, which goes empty.
class PrebidMaxPreloadedBannerAd {
  /// Creates a banner; nothing is requested until [load]. The parameters are
  /// those of [PrebidMaxBannerAd]; [adaptive] spans [adaptiveWidth], or
  /// [width] when it is null.
  PrebidMaxPreloadedBannerAd({
    required this.configId,
    required this.maxAdUnitId,
    required this.width,
    required this.height,
    this.additionalSizes,
    this.adaptive = false,
    this.adaptiveWidth,
    this.adFormats,
    this.videoParameters,
    this.refreshIntervalSeconds,
    this.adPosition,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.pbAdSlot,
    this.gpid,
    this.listener,
  });

  static final _channel = CompanionAdChannel(
    'prebid_mobile_sdk_max/preloaded_banner',
  );

  /// See [PrebidMaxBannerAd.configId].
  final String configId;

  /// See [PrebidMaxBannerAd.maxAdUnitId].
  final String maxAdUnitId;

  /// See [PrebidMaxBannerAd.width]. With [adaptive], also the width the
  /// adaptive banner spans, unless [adaptiveWidth] is set.
  final int width;

  /// See [PrebidMaxBannerAd.height].
  final int height;

  /// See [PrebidMaxBannerAd.additionalSizes].
  final List<Size>? additionalSizes;

  /// Whether the MAX view is an adaptive banner spanning [width] (the banner
  /// loads before any layout, so it can't measure the available width), at
  /// the height MAX computes for it. Ignored for a 300x250 (MREC) banner.
  final bool adaptive;

  /// The width, in dp, the MAX adaptive banner spans when [adaptive];
  /// [width] when null. [width] stays the Prebid request size, so a
  /// full-width adaptive banner can still ask bidders for a 320x50 bid.
  final double? adaptiveWidth;

  /// See [PrebidMaxBannerAd.adFormats].
  final Set<PrebidAdFormat>? adFormats;

  /// See [PrebidMaxBannerAd.videoParameters].
  final VideoParameters? videoParameters;

  /// See [PrebidMaxBannerAd.refreshIntervalSeconds].
  final int? refreshIntervalSeconds;

  /// See [PrebidMaxBannerAd.adPosition].
  final PrebidAdPosition? adPosition;

  /// See [PrebidMaxBannerAd.impOrtbConfig].
  final String? impOrtbConfig;

  /// See [PrebidMaxBannerAd.globalOrtbConfig].
  final String? globalOrtbConfig;

  /// See [PrebidMaxBannerAd.pbAdSlot].
  final String? pbAdSlot;

  /// Global Placement ID (`imp.ext.gpid`), e.g. `/1111/home`. Sent in
  /// [impOrtbConfig]; a `gpid` already there wins.
  final String? gpid;

  /// Listener for banner ad events. Pass a [PrebidMaxBannerAdListener] to
  /// also get MAX's expand / collapse, display-failure and revenue events.
  final PrebidBannerAdListener? listener;

  bool get _isAdaptive => adaptive && !(width == 300 && height == 250);

  late final PreloadedBanner _banner = PreloadedBanner.companion(
    viewType: 'prebid_mobile_sdk_max/banner',
    channel: _channel,
    size: Size(width.toDouble(), height.toDouble()),
    config: () => {
      ..._maxBannerConfig(
        configId: configId,
        maxAdUnitId: maxAdUnitId,
        width: width,
        height: height,
        autoLoad: true,
        adaptive: adaptive,
        adPosition: adPosition,
        impOrtbConfig: impOrtbWithGpid(impOrtbConfig, gpid),
        globalOrtbConfig: globalOrtbConfig,
        pbAdSlot: pbAdSlot,
        additionalSizes: additionalSizes,
        adFormats: adFormats,
        videoParameters: videoParameters,
        refreshIntervalSeconds: refreshIntervalSeconds,
      ),
      if (_isAdaptive) 'adaptiveWidth': adaptiveWidth ?? width,
      ...debugDropBidArgs(),
    },
    onEvent: (call) => _dispatchMaxBannerEvent(listener, call),
  );

  /// The slot size: [width] x [height] until the native SDK reports the
  /// rendered creative's size.
  Size get size => _banner.size;

  /// Runs the auction and loads the MAX view off screen; calling it again
  /// reloads the banner, and after [destroy] it starts afresh.
  Future<void> load() => _banner.load();

  /// Stops auto-refresh. Does nothing without a loaded banner.
  Future<void> stopRefresh() => _banner.stopRefresh();

  /// Destroys the native banner; a view showing it goes empty until the
  /// next [load].
  Future<void> destroy() => _banner.destroy();
}

/// Shows a [PrebidMaxPreloadedBannerAd] at the size it reports; the slot
/// stays empty while the banner isn't loaded. Removing the view keeps the
/// banner loaded.
class PrebidMaxPreloadedBannerAdView extends StatelessWidget {
  /// Creates a view of [ad].
  const PrebidMaxPreloadedBannerAdView({super.key, required this.ad});

  /// The banner to show.
  final PrebidMaxPreloadedBannerAd ad;

  @override
  Widget build(BuildContext context) => PreloadedBannerView(banner: ad._banner);
}
