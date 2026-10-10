import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/companion.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show
        PrebidAdFormat,
        PrebidAdPosition,
        PrebidBannerAdController,
        PrebidBannerAdListener,
        PrebidBannerVideoListener,
        VideoParameters,
        VideoPlacementType;

/// A banner ad rendered by **Google Ad Manager** with Prebid demand.
///
/// Prebid runs the auction and, via its GAM event handler, GAM renders either
/// the winning Prebid creative (through a Prebid line item + the Prebid
/// Universal Creative) or a direct-sold GAM ad. Contrast with the core
/// `PrebidBannerAd`, where the Prebid SDK renders directly.
///
/// On Android a load made before the Prebid SDK finished initializing
/// reports `onAdFailed` ("The Prebid SDK is not initialized"): Prebid Android
/// drops such requests, so the banner would never load.
class PrebidGamBannerAd extends StatefulWidget {
  /// Creates a [PrebidGamBannerAd] widget.
  const PrebidGamBannerAd({
    super.key,
    required this.configId,
    required this.gamAdUnitId,
    required this.width,
    required this.height,
    this.additionalSizes,
    this.isVideo = false,
    this.adFormats,
    this.pbAdSlot,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.videoParameters,
    this.autoLoad = true,
    this.refreshIntervalSeconds,
    this.customTargeting,
    this.videoPlacementType,
    this.controller,
    this.adPosition,
    this.listener,
    this.videoListener,
  });

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The Google Ad Manager ad unit ID (e.g. `/1234567/your-ad-unit`).
  final String gamAdUnitId;

  /// The desired width of the banner ad in dp.
  final int width;

  /// The desired height of the banner ad in dp.
  final int height;

  /// Further sizes the slot accepts besides [width] x [height] (a multisize
  /// banner, e.g. `[Size(300, 250)]` next to 320x50). Passed to the GAM event
  /// handler as valid ad sizes, from which Prebid derives the request sizes.
  final List<Size>? additionalSizes;

  /// Whether this banner should display video ads.
  ///
  /// Ignored when [adFormats] is set.
  final bool isVideo;

  /// Formats to request — e.g. `{PrebidAdFormat.banner, PrebidAdFormat.video}` for a
  /// multiformat banner (Prebid 3.4). Overrides [isVideo] when set.
  final Set<PrebidAdFormat>? adFormats;

  /// Prebid ad slot (`imp.ext.data.pbadslot`).
  final String? pbAdSlot;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp` (e.g.
  /// `{"ext":{"gpid":"/1111/home"}}`).
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only (merged over
  /// `PrebidTargeting.setGlobalOrtbConfig`).
  final String? globalOrtbConfig;

  /// OpenRTB video parameters for an outstream video banner. **iOS only**:
  /// Prebid Android's `BannerView` has no video-parameters setter (use
  /// [videoPlacementType] there). An explicit `placement` here overrides
  /// [videoPlacementType].
  final VideoParameters? videoParameters;

  /// Whether the ad should load automatically when the widget is created.
  final bool autoLoad;

  /// Auto-refresh interval in seconds. `null` (default) or `0` disables
  /// auto-refresh on both platforms; positive values are clamped by Prebid to
  /// its supported range (Android 30–120 s, iOS 15–120 s).
  final int? refreshIntervalSeconds;

  /// Custom key-values added to the Google Ad Manager request (Prebid 3.4).
  /// Prebid's own `hb_*` keys take precedence on conflict.
  final Map<String, String>? customTargeting;

  /// Outstream video placement when the banner requests video. Defaults to
  /// [VideoPlacementType.inBanner].
  final VideoPlacementType? videoPlacementType;

  /// Optional controller to load on demand (`autoLoad: false`) or stop
  /// auto-refresh.
  final PrebidBannerAdController? controller;

  /// Ad position on screen (`imp.banner.pos`).
  final PrebidAdPosition? adPosition;

  /// Listener for banner ad events.
  final PrebidBannerAdListener? listener;

  /// Listener for video playback events (outstream video creatives).
  final PrebidBannerVideoListener? videoListener;

  @override
  State<PrebidGamBannerAd> createState() => _PrebidGamBannerAdState();
}

class _PrebidGamBannerAdState extends State<PrebidGamBannerAd>
    with AdViewState<PrebidGamBannerAd> {
  @override
  String get viewType => 'prebid_mobile_sdk_gam/banner';

  @override
  PrebidBannerAdController? controllerOf(PrebidGamBannerAd widget) =>
      widget.controller;

  @override
  bool autoLoadOf(PrebidGamBannerAd widget) => widget.autoLoad;

  @override
  Map<String, Object?> configOf(PrebidGamBannerAd widget) => {
    'configId': widget.configId,
    'gamAdUnitId': widget.gamAdUnitId,
    'width': widget.width,
    'height': widget.height,
    'isVideo': widget.isVideo,
    'autoLoad': widget.autoLoad,
    'adPosition': ?widget.adPosition?.value,
    if (widget.additionalSizes case final sizes?)
      'additionalSizes': [
        for (final size in sizes) ...[size.width.round(), size.height.round()],
      ],
    'adFormats': ?widget.adFormats?.map((f) => f.name).toList(),
    'pbAdSlot': ?widget.pbAdSlot,
    'impOrtbConfig': ?widget.impOrtbConfig,
    'globalOrtbConfig': ?widget.globalOrtbConfig,
    'videoParameters': ?widget.videoParameters?.toMap(),
    'refreshIntervalSeconds': ?widget.refreshIntervalSeconds,
    'customTargeting': ?widget.customTargeting,
    'videoPlacementType': ?widget.videoPlacementType?.name,
  };

  /// The slot starts at the requested size and adopts the rendered
  /// creative's size once the native SDK reports it.
  @override
  Widget build(BuildContext context) => SizedBox(
    width: reportedWidth ?? widget.width.toDouble(),
    height: reportedHeight ?? widget.height.toDouble(),
    child: buildAdView(),
  );

  @override
  void onViewEvent(MethodCall call) =>
      dispatchBannerEvent(widget.listener, widget.videoListener, call);
}
