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
  Map<String, Object?> configOf(PrebidMaxBannerAd widget) => {
    'configId': widget.configId,
    'maxAdUnitId': widget.maxAdUnitId,
    'width': widget.width,
    'height': widget.height,
    'autoLoad': widget.autoLoad,
    'adPosition': ?widget.adPosition?.value,
    'impOrtbConfig': ?widget.impOrtbConfig,
    'globalOrtbConfig': ?widget.globalOrtbConfig,
    'pbAdSlot': ?widget.pbAdSlot,
    if (widget.additionalSizes case final sizes?)
      'additionalSizes': [
        for (final size in sizes) ...[size.width.round(), size.height.round()],
      ],
    if (widget.adaptive) 'adaptive': true,
    'adFormats': ?widget.adFormats?.map((f) => f.name).toList(),
    'videoParameters': ?widget.videoParameters?.toMap(),
    'refreshIntervalSeconds': ?widget.refreshIntervalSeconds,
  };

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
  void onViewEvent(MethodCall call) {
    if (dispatchBannerEvent(widget.listener, null, call)) return;
    final listener = widget.listener;
    final max = listener is PrebidMaxBannerAdListener ? listener : null;
    switch (call.method) {
      case 'onAdDisplayFailed':
        final error = adEventError(call.arguments);
        listener?.onAdFailed?.call(error);
        max?.onAdDisplayFailed?.call(error);
      case 'onAdExpanded':
        max?.onAdExpanded?.call();
      case 'onAdCollapsed':
        max?.onAdCollapsed?.call();
      case 'onAdRevenuePaid':
        max?.onAdRevenuePaid?.call(maxAdRevenueFrom(call.arguments as Map?));
    }
  }
}
