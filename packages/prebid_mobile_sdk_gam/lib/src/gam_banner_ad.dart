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
  Map<String, Object?> configOf(PrebidGamBannerAd widget) => _gamBannerConfig(
    configId: widget.configId,
    gamAdUnitId: widget.gamAdUnitId,
    width: widget.width,
    height: widget.height,
    isVideo: widget.isVideo,
    autoLoad: widget.autoLoad,
    adPosition: widget.adPosition,
    additionalSizes: widget.additionalSizes,
    adFormats: widget.adFormats,
    pbAdSlot: widget.pbAdSlot,
    impOrtbConfig: widget.impOrtbConfig,
    globalOrtbConfig: widget.globalOrtbConfig,
    videoParameters: widget.videoParameters,
    refreshIntervalSeconds: widget.refreshIntervalSeconds,
    customTargeting: widget.customTargeting,
    videoPlacementType: widget.videoPlacementType,
  );

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

/// The creation params of a native GAM banner, for [PrebidGamBannerAd] and
/// [PrebidGamPreloadedBannerAd].
Map<String, Object?> _gamBannerConfig({
  required String configId,
  required String gamAdUnitId,
  required int width,
  required int height,
  required bool isVideo,
  required bool autoLoad,
  PrebidAdPosition? adPosition,
  List<Size>? additionalSizes,
  Set<PrebidAdFormat>? adFormats,
  String? pbAdSlot,
  String? impOrtbConfig,
  String? globalOrtbConfig,
  VideoParameters? videoParameters,
  int? refreshIntervalSeconds,
  Map<String, String>? customTargeting,
  VideoPlacementType? videoPlacementType,
}) => {
  'configId': configId,
  'gamAdUnitId': gamAdUnitId,
  'width': width,
  'height': height,
  'isVideo': isVideo,
  'autoLoad': autoLoad,
  'adPosition': ?adPosition?.value,
  if (additionalSizes case final sizes?)
    'additionalSizes': [
      for (final size in sizes) ...[size.width.round(), size.height.round()],
    ],
  'adFormats': ?adFormats?.map((f) => f.name).toList(),
  'pbAdSlot': ?pbAdSlot,
  'impOrtbConfig': ?impOrtbConfig,
  'globalOrtbConfig': ?globalOrtbConfig,
  'videoParameters': ?videoParameters?.toMap(),
  'refreshIntervalSeconds': ?refreshIntervalSeconds,
  'customTargeting': ?customTargeting,
  'videoPlacementType': ?videoPlacementType?.name,
};

/// A [PrebidGamBannerAd] loaded before its slot is on screen and kept
/// across the views showing it: [load] it, show it with a
/// [PrebidGamPreloadedBannerAdView], and [destroy] it when you no longer
/// need it. In a scrolling list, a slot scrolled away and back shows the
/// same ad instead of running a new auction.
///
/// The banner shows in one view at a time: a view built later takes it over
/// from the one showing it, which goes empty.
class PrebidGamPreloadedBannerAd {
  /// Creates a banner; nothing is requested until [load]. The parameters are
  /// those of [PrebidGamBannerAd].
  PrebidGamPreloadedBannerAd({
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
    this.refreshIntervalSeconds,
    this.customTargeting,
    this.videoPlacementType,
    this.adPosition,
    this.listener,
    this.videoListener,
  });

  static final _channel = CompanionAdChannel(
    'prebid_mobile_sdk_gam/preloaded_banner',
  );

  /// See [PrebidGamBannerAd.configId].
  final String configId;

  /// See [PrebidGamBannerAd.gamAdUnitId].
  final String gamAdUnitId;

  /// See [PrebidGamBannerAd.width].
  final int width;

  /// See [PrebidGamBannerAd.height].
  final int height;

  /// See [PrebidGamBannerAd.additionalSizes].
  final List<Size>? additionalSizes;

  /// See [PrebidGamBannerAd.isVideo].
  final bool isVideo;

  /// See [PrebidGamBannerAd.adFormats].
  final Set<PrebidAdFormat>? adFormats;

  /// See [PrebidGamBannerAd.pbAdSlot].
  final String? pbAdSlot;

  /// See [PrebidGamBannerAd.impOrtbConfig].
  final String? impOrtbConfig;

  /// See [PrebidGamBannerAd.globalOrtbConfig].
  final String? globalOrtbConfig;

  /// See [PrebidGamBannerAd.videoParameters].
  final VideoParameters? videoParameters;

  /// See [PrebidGamBannerAd.refreshIntervalSeconds]. Prebid refreshes the
  /// banner only while it is on screen.
  final int? refreshIntervalSeconds;

  /// See [PrebidGamBannerAd.customTargeting].
  final Map<String, String>? customTargeting;

  /// See [PrebidGamBannerAd.videoPlacementType].
  final VideoPlacementType? videoPlacementType;

  /// See [PrebidGamBannerAd.adPosition].
  final PrebidAdPosition? adPosition;

  /// Listener for banner ad events.
  final PrebidBannerAdListener? listener;

  /// Listener for video playback events (outstream video creatives).
  final PrebidBannerVideoListener? videoListener;

  late final PreloadedBanner _banner = PreloadedBanner.companion(
    viewType: 'prebid_mobile_sdk_gam/banner',
    channel: _channel,
    size: Size(width.toDouble(), height.toDouble()),
    config: () => _gamBannerConfig(
      configId: configId,
      gamAdUnitId: gamAdUnitId,
      width: width,
      height: height,
      isVideo: isVideo,
      autoLoad: true,
      adPosition: adPosition,
      additionalSizes: additionalSizes,
      adFormats: adFormats,
      pbAdSlot: pbAdSlot,
      impOrtbConfig: impOrtbConfig,
      globalOrtbConfig: globalOrtbConfig,
      videoParameters: videoParameters,
      refreshIntervalSeconds: refreshIntervalSeconds,
      customTargeting: customTargeting,
      videoPlacementType: videoPlacementType,
    ),
    onEvent: (call) => dispatchBannerEvent(listener, videoListener, call),
  );

  /// The slot size: [width] x [height] until the native SDK reports the
  /// rendered creative's size.
  Size get size => _banner.size;

  /// Runs the auction and renders the winner off screen; calling it again
  /// reloads the banner, and after [destroy] it starts afresh.
  Future<void> load() => _banner.load();

  /// Stops auto-refresh. Does nothing without a loaded banner.
  Future<void> stopRefresh() => _banner.stopRefresh();

  /// Destroys the native banner; a view showing it goes empty until the
  /// next [load].
  Future<void> destroy() => _banner.destroy();
}

/// Shows a [PrebidGamPreloadedBannerAd] at the size it reports; the slot
/// stays empty while the banner isn't loaded. Removing the view keeps the
/// banner loaded.
class PrebidGamPreloadedBannerAdView extends StatelessWidget {
  /// Creates a view of [ad].
  const PrebidGamPreloadedBannerAdView({super.key, required this.ad});

  /// The banner to show.
  final PrebidGamPreloadedBannerAd ad;

  @override
  Widget build(BuildContext context) => PreloadedBannerView(banner: ad._banner);
}
