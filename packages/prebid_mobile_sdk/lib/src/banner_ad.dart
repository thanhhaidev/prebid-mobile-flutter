import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'ad_enums.dart';
import 'ad_listener.dart';
import 'companion/ad_view_channel.dart';
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

  /// Records the bid of a loaded banner. Called by the banner widgets; not
  /// for app code.
  void reportWinningBid(PrebidWinningBid? bid) => _winningBid = bid;

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

  /// Binds the controller to a banner view's method channel. Called by the
  /// banner widgets (including `PrebidGamBannerAd`); not for app code.
  ///
  /// [autoLoaded] tells whether the view already loads on its own; a
  /// [loadAd] queued before the view existed then runs no second auction.
  void attachChannel(MethodChannel channel, {bool autoLoaded = false}) {
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

  /// Unbinds the controller from [channel] when its banner is disposed.
  void detachChannel(MethodChannel channel) {
    if (identical(_channel, channel)) _channel = null;
  }
}

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

class _PrebidBannerAdState extends State<PrebidBannerAd> {
  /// Current slot size. Starts at the requested size and is updated to the
  /// actual rendered creative size once the native SDK reports it, so a won
  /// creative larger than the request (e.g. a multisize banner) is not clipped
  /// or overflowed.
  late double _width = widget.width.toDouble();
  late double _height = widget.height.toDouble();

  /// The native view's channel, listened to before the view exists; a new
  /// view (changed configuration) gets a new one.
  late AdViewChannel _view = _listen();

  AdViewChannel _listen() =>
      AdViewChannel('prebid_mobile_sdk/banner_ad', _onNativeEvent);

  @override
  void didUpdateWidget(PrebidBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_creationParams(oldWidget).toString() !=
        _creationParams(widget).toString()) {
      // The native view reads its configuration once, so a changed config
      // gets a new view (keyed below) that starts at the requested size.
      _width = widget.width.toDouble();
      _height = widget.height.toDouble();
      // The old view is disposed: a `controller.loadAd()` made before the
      // new view exists is queued and replayed on it (by `attachChannel`).
      _detach(oldWidget.controller);
      _view = _listen();
      return;
    }
    if (_attached && !identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.detachChannel(_view.methodChannel);
      widget.controller?.attachChannel(
        _view.methodChannel,
        autoLoaded: widget.autoLoad,
      );
    }
  }

  bool _attached = false;

  void _detach(PrebidBannerAdController? controller) {
    _view.dispose();
    controller?.detachChannel(_view.methodChannel);
    _attached = false;
  }

  static Map<String, dynamic> _creationParams(PrebidBannerAd widget) {
    return <String, dynamic>{
      'configId': widget.configId,
      'width': widget.width,
      'height': widget.height,
      'isVideo': widget.isVideo,
      'autoLoad': widget.autoLoad,
      if (widget.additionalSizes != null)
        'additionalSizes': [
          for (final size in widget.additionalSizes!) ...[
            size.width.round(),
            size.height.round(),
          ],
        ],
      if (widget.refreshIntervalSeconds != null)
        'refreshIntervalSeconds': widget.refreshIntervalSeconds,
      if (widget.adFormats != null)
        'adFormats': widget.adFormats!.map((f) => f.name).toList(),
      if (widget.pbAdSlot != null) 'pbAdSlot': widget.pbAdSlot,
      if (widget.adPosition != null) 'adPosition': widget.adPosition!.value,
      if (widget.videoParameters != null)
        'videoParameters': widget.videoParameters!.toMap(),
      if (widget.impOrtbConfig != null) 'impOrtbConfig': widget.impOrtbConfig,
      if (widget.globalOrtbConfig != null)
        'globalOrtbConfig': widget.globalOrtbConfig,
      if (widget.videoPlacementType != null)
        'videoPlacementType': widget.videoPlacementType!.name,
    };
  }

  @override
  Widget build(BuildContext context) {
    final creationParams = {..._creationParams(widget), 'channelId': _view.id};

    // The slot sizes dynamically: it starts at the requested size and adopts
    // the actual rendered creative size once the native SDK reports it.
    return SizedBox(
      width: _width,
      height: _height,
      child: _buildPlatformView(creationParams),
    );
  }

  Widget _buildPlatformView(Map<String, dynamic> creationParams) {
    // A new channel id means a new native view (changed configuration).
    final key = ValueKey(_view.id);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        key: key,
        viewType: 'prebid_mobile_sdk/banner_ad',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        key: key,
        viewType: 'prebid_mobile_sdk/banner_ad',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
    return const SizedBox.shrink();
  }

  void _onPlatformViewCreated(int viewId) {
    _attached = true;
    widget.controller?.attachChannel(
      _view.methodChannel,
      autoLoaded: widget.autoLoad,
    );
  }

  // Set up even without a listener so the slot can still resize to the
  // rendered creative via `onAdSize`.
  Future<dynamic> _onNativeEvent(MethodCall call) async {
    switch (call.method) {
      case 'onAdSize':
        final args = call.arguments as Map?;
        final w = (args?['width'] as num?)?.toDouble();
        final h = (args?['height'] as num?)?.toDouble();
        if (w != null && h != null && w > 0 && h > 0 && mounted) {
          setState(() {
            _width = w;
            _height = h;
          });
        }
      case 'onAdLoaded':
        widget.controller?.reportWinningBid(
          PrebidWinningBid.fromPayload(call.arguments),
        );
        widget.listener?.onAdLoaded?.call();
      case 'onAdDisplayed':
        widget.listener?.onAdDisplayed?.call();
      case 'onAdFailed':
        widget.listener?.onAdFailed?.call(call.arguments as String? ?? '');
      case 'onAdClicked':
        widget.listener?.onAdClicked?.call();
      case 'onAdClosed':
        widget.listener?.onAdClosed?.call();
      case 'onAdExpired':
        widget.listener?.onAdExpired?.call();
      default:
        widget.videoListener?.dispatch(call.method);
    }
  }

  @override
  void dispose() {
    _detach(widget.controller);
    super.dispose();
  }
}
