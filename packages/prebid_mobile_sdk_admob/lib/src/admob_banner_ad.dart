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

import 'admob_testing.dart';

/// A banner ad mediated by **Google AdMob** with Prebid demand.
///
/// Prebid runs the auction via a `MediationBannerAdUnit` and passes the winning
/// bid to AdMob through the Prebid AdMob adapter; AdMob then renders either the
/// Prebid creative or a competing AdMob creative. Contrast with the core
/// `PrebidBannerAd`, where the Prebid SDK renders directly.
///
/// On Android a banner created before the Prebid SDK finished initializing
/// reports `onAdFailed` ("The Prebid SDK is not initialized"): Prebid Android
/// drops such requests, so AdMob's waterfall would never run.
class PrebidAdMobBannerAd extends StatefulWidget {
  /// Creates a [PrebidAdMobBannerAd] widget.
  const PrebidAdMobBannerAd({
    super.key,
    required this.configId,
    required this.adMobAdUnitId,
    required this.width,
    required this.height,
    this.additionalSizes,
    this.adFormats,
    this.videoParameters,
    this.adaptive = false,
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

  /// The AdMob ad unit ID (e.g. `ca-app-pub-3940256099942544/6300978111`).
  final String adMobAdUnitId;

  /// The desired width of the banner ad in dp.
  final int width;

  /// The desired height of the banner ad in dp.
  final int height;

  /// Further sizes Prebid may bid on besides [width] x [height] (e.g.
  /// `[Size(728, 90)]`), sent in the Prebid request
  /// (`MediationBannerAdUnit.addAdditionalSize` / `additionalSizes`). The
  /// AdMob view keeps its own size — [adaptive] or [width] x [height].
  final List<Size>? additionalSizes;

  /// Formats Prebid requests — e.g. `{PrebidAdFormat.banner,
  /// PrebidAdFormat.video}` for a multiformat banner, or
  /// `{PrebidAdFormat.video}` for an outstream video banner
  /// (`MediationBannerAdUnit.setAdUnitFormats` / `adFormats`). `null` or an
  /// empty set requests a display banner. AdMob renders whichever creative
  /// wins.
  final Set<PrebidAdFormat>? adFormats;

  /// Video signals for a video or multiformat banner ([adFormats] with
  /// [PrebidAdFormat.video]). iOS sends every field from the mediation
  /// banner's `videoParameters`; Prebid Android's `MediationBannerAdUnit` has
  /// no video-parameters setter, so Android sends the SDK's defaults.
  final VideoParameters? videoParameters;

  /// Whether the AdMob view uses AdMob's **landscape inline adaptive** banner
  /// size for the full width available to the widget, instead of a fixed
  /// [width] x [height]. [width] x [height] (plus [additionalSizes]) remain
  /// the Prebid request sizes. The slot resizes to the adaptive height AdMob
  /// reports once the ad loads; the width is measured once, at the first
  /// layout.
  final bool adaptive;

  /// Prebid auto-refresh interval in seconds; each refresh runs a new auction
  /// and reloads the AdMob view. `null` (default) or `0` disables
  /// auto-refresh on both platforms; positive values are clamped by Prebid to
  /// its supported range (Android 30–120 s, iOS 15–120 s). Turn off the AdMob
  /// ad unit's own refresh in the AdMob UI so the two do not stack. Stop it
  /// at runtime with [PrebidBannerAdController.stopRefresh].
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

  /// Listener for banner ad events.
  final PrebidBannerAdListener? listener;

  @override
  State<PrebidAdMobBannerAd> createState() => _PrebidAdMobBannerAdState();
}

class _PrebidAdMobBannerAdState extends State<PrebidAdMobBannerAd>
    with AdViewState<PrebidAdMobBannerAd> {
  /// [PrebidAdMob.debugDropBidProbability] as read when the view was created.
  Map<String, Object> _debugArgs = debugDropBidArgs();

  @override
  String get viewType => 'prebid_mobile_sdk_admob/banner';

  @override
  PrebidBannerAdController? controllerOf(PrebidAdMobBannerAd widget) =>
      widget.controller;

  @override
  bool autoLoadOf(PrebidAdMobBannerAd widget) => widget.autoLoad;

  @override
  void onViewReplaced() => _debugArgs = debugDropBidArgs();

  @override
  Map<String, Object?> configOf(PrebidAdMobBannerAd widget) => {
    'configId': widget.configId,
    'adMobAdUnitId': widget.adMobAdUnitId,
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
    'adFormats': ?widget.adFormats?.map((f) => f.name).toList(),
    'videoParameters': ?widget.videoParameters?.toMap(),
    if (widget.adaptive) 'adaptive': true,
    'refreshIntervalSeconds': ?widget.refreshIntervalSeconds,
  };

  /// The slot starts at the requested size (an adaptive one at the available
  /// width) and adopts the rendered creative's size once the native SDK
  /// reports it.
  @override
  Widget build(BuildContext context) {
    if (!widget.adaptive) {
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
      dispatchBannerEvent(widget.listener, null, call);
}
