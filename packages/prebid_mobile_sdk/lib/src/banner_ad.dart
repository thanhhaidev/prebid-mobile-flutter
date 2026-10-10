import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'ad_enums.dart';
import 'ad_listener.dart';
import 'companion/ad_view_state.dart';
import 'internal/ortb.dart';
import 'video_parameters.dart';

/// The winning bid of a loaded Prebid-rendered banner
/// ([PrebidBannerAdController.winningBid]).
class PrebidWinningBid {
  /// Creates a [PrebidWinningBid].
  const PrebidWinningBid({
    required this.price,
    required this.size,
    this.bidder,
    this.targetingKeywords = const {},
  });

  /// Reads the `onAdLoaded` payload of a banner view; null without a bid.
  static PrebidWinningBid? fromPayload(Object? raw) {
    if (raw is! Map) return null;
    final price = (raw['price'] as num?)?.toDouble();
    if (price == null) return null;
    return PrebidWinningBid(
      price: price,
      bidder: raw['bidder'] as String?,
      size: Size(
        (raw['width'] as num?)?.toDouble() ?? 0,
        (raw['height'] as num?)?.toDouble() ?? 0,
      ),
      targetingKeywords: {
        for (final MapEntry(:key, :value)
            in (raw['targetingKeywords'] as Map? ?? const {}).entries)
          if (key is String && value is String) key: value,
      },
    );
  }

  /// The bid price (CPM, in the auction currency).
  final double price;

  /// The winning bidder (`hb_bidder`), when Prebid Server reports it.
  final String? bidder;

  /// The creative size in density-independent pixels.
  final Size size;

  /// The bid's targeting keywords (`hb_pb`, `hb_bidder`, ...).
  final Map<String, String> targetingKeywords;
}

/// Controls a [PrebidBannerAd]: load on demand (with `autoLoad: false`) or
/// stop auto-refresh.
///
/// ```dart
/// final controller = PrebidBannerAdController();
/// PrebidBannerAd(configId: '...', width: 320, height: 50,
///     autoLoad: false, controller: controller);
/// // later
/// await controller.loadAd();
/// ```
class PrebidBannerAdController {
  /// Creates a controller; pass it to one banner widget's `controller`.
  PrebidBannerAdController();

  MethodChannel? _channel;
  bool _pendingLoad = false;

  /// The winning bid of the banner's last load, for analytics; null before
  /// the first load and when the last one had no bid.
  PrebidWinningBid? get winningBid => _winningBid;
  PrebidWinningBid? _winningBid;

  /// Loads (or reloads) the banner. Safe to call before the banner's native
  /// view exists — the load runs once it is created.
  Future<void> loadAd() async {
    final channel = _channel;
    if (channel == null) {
      _pendingLoad = true;
      return;
    }
    await channel.invokeMethod<void>('loadAd');
  }

  /// Stops auto-refresh for the banner.
  Future<void> stopRefresh() async {
    await _channel?.invokeMethod<void>('stopRefresh');
  }

  void _attach(MethodChannel channel, {required bool autoLoaded}) {
    _channel = channel;
    if (_pendingLoad) {
      _pendingLoad = false;
      if (!autoLoaded) {
        unawaited(
          channel.invokeMethod<void>('loadAd').catchError((Object _) {}),
        );
      }
    }
  }

  void _detach(MethodChannel channel) {
    if (identical(_channel, channel)) _channel = null;
  }
}

/// Binds [controller] to a banner view's [channel]; used by the banner
/// widgets (`AdViewState`), not exported to apps.
///
/// [autoLoaded] tells whether the view already loads on its own; a
/// `loadAd` queued before the view existed then runs no second auction.
void attachBannerController(
  PrebidBannerAdController controller,
  MethodChannel channel, {
  bool autoLoaded = false,
}) => controller._attach(channel, autoLoaded: autoLoaded);

/// Unbinds [controller] from [channel] when its banner view goes away.
void detachBannerController(
  PrebidBannerAdController controller,
  MethodChannel channel,
) => controller._detach(channel);

/// A banner ad widget that displays a Prebid rendered banner.
///
/// Uses a native PlatformView to render the banner ad on both Android and iOS.
class PrebidBannerAd extends StatefulWidget {
  /// Creates a [PrebidBannerAd] widget.
  const PrebidBannerAd({
    super.key,
    required this.configId,
    required this.width,
    required this.height,
    this.additionalSizes,
    this.isVideo = false,
    this.adFormats,
    this.pbAdSlot,
    this.gpid,
    this.adPosition,
    this.videoParameters,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.controller,
    this.autoLoad = true,
    this.refreshIntervalSeconds,
    this.videoPlacementType,
    this.listener,
    this.videoListener,
  });

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The desired width of the banner ad in dp.
  final int width;

  /// The desired height of the banner ad in dp.
  final int height;

  /// Further sizes the slot accepts besides [width] x [height] (a multisize
  /// banner, e.g. `[Size(300, 250)]` next to 320x50). The slot resizes to the
  /// winning creative.
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

  /// Global Placement ID (`imp.ext.gpid`), added to [impOrtbConfig] (a
  /// `gpid` already there wins).
  final String? gpid;

  /// Ad position on screen (`imp.banner.pos`).
  final PrebidAdPosition? adPosition;

  /// Video signals for video banners. iOS only: Prebid Android's banner has
  /// no video-parameters setter, so Android sends the SDK's defaults.
  final VideoParameters? videoParameters;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp` (e.g.
  /// `{"ext":{"gpid":"/1111/home"}}`).
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only (merged over
  /// [PrebidTargeting.setGlobalOrtbConfig]).
  final String? globalOrtbConfig;

  /// Optional controller to load on demand / stop refresh, and to read the
  /// [PrebidBannerAdController.winningBid].
  final PrebidBannerAdController? controller;

  /// Whether the ad should load automatically when the widget is created.
  final bool autoLoad;

  /// Auto-refresh interval in seconds.
  ///
  /// If set, the banner will automatically request new ads at this interval.
  /// Prebid clamps it to 30–120 s on Android and 15–120 s on iOS.
  /// `null` (default) or `0` disables auto-refresh on both platforms.
  final int? refreshIntervalSeconds;

  /// Outstream video placement (`imp.video.placement`) when the banner
  /// requests video. Defaults to [VideoPlacementType.inBanner].
  final VideoPlacementType? videoPlacementType;

  /// Listener for banner ad events.
  final PrebidBannerAdListener? listener;

  /// Listener for video playback events (outstream video creatives).
  final PrebidBannerVideoListener? videoListener;

  @override
  State<PrebidBannerAd> createState() => _PrebidBannerAdState();
}

class _PrebidBannerAdState extends State<PrebidBannerAd>
    with AdViewState<PrebidBannerAd> {
  @override
  String get viewType => 'prebid_mobile_sdk/banner_ad';

  @override
  PrebidBannerAdController? controllerOf(PrebidBannerAd widget) =>
      widget.controller;

  @override
  bool autoLoadOf(PrebidBannerAd widget) => widget.autoLoad;

  @override
  Map<String, Object?> configOf(PrebidBannerAd widget) => {
    'configId': widget.configId,
    'width': widget.width,
    'height': widget.height,
    'isVideo': widget.isVideo,
    'autoLoad': widget.autoLoad,
    if (widget.additionalSizes case final sizes?)
      'additionalSizes': [
        for (final size in sizes) ...[size.width.round(), size.height.round()],
      ],
    'refreshIntervalSeconds': ?widget.refreshIntervalSeconds,
    'adFormats': ?widget.adFormats?.map((f) => f.name).toList(),
    'pbAdSlot': ?widget.pbAdSlot,
    'adPosition': ?widget.adPosition?.value,
    'videoParameters': ?widget.videoParameters?.toMap(),
    'impOrtbConfig': ?impOrtbWithGpid(widget.impOrtbConfig, widget.gpid),
    'globalOrtbConfig': ?widget.globalOrtbConfig,
    'videoPlacementType': ?widget.videoPlacementType?.name,
  };

  // The slot starts at the requested size and adopts the rendered creative's
  // size once the native SDK reports it, so a creative larger than the
  // request (a multisize banner) is neither clipped nor overflowing.
  @override
  Widget build(BuildContext context) => SizedBox(
    width: reportedWidth ?? widget.width.toDouble(),
    height: reportedHeight ?? widget.height.toDouble(),
    child: buildAdView(),
  );

  @override
  void onViewEvent(MethodCall call) {
    if (call.method == 'onAdLoaded') {
      widget.controller?._winningBid = PrebidWinningBid.fromPayload(
        call.arguments,
      );
    }
    dispatchBannerEvent(widget.listener, widget.videoListener, call);
  }
}
