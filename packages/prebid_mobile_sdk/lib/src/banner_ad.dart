import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'ad_enums.dart';
import 'ad_listener.dart';

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
  MethodChannel? _channel;
  bool _pendingLoad = false;

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
  void attachChannel(MethodChannel channel) {
    _channel = channel;
    if (_pendingLoad) {
      _pendingLoad = false;
      channel.invokeMethod<void>('loadAd');
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
  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The desired width of the banner ad in dp.
  final int width;

  /// The desired height of the banner ad in dp.
  final int height;

  /// Whether this banner should display video ads.
  ///
  /// Ignored when [adFormats] is set.
  final bool isVideo;

  /// Formats to request — e.g. `{AdFormat.banner, AdFormat.video}` for a
  /// multiformat banner (Prebid 3.4). Overrides [isVideo] when set.
  final Set<AdFormat>? adFormats;

  /// Prebid ad slot (`imp.ext.data.pbadslot`).
  final String? pbAdSlot;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp` (e.g.
  /// `{"ext":{"gpid":"/1111/home"}}`).
  final String? impOrtbConfig;

  /// Optional controller to load on demand / stop refresh.
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

  /// Creates a [PrebidBannerAd] widget.
  const PrebidBannerAd({
    super.key,
    required this.configId,
    required this.width,
    required this.height,
    this.isVideo = false,
    this.adFormats,
    this.pbAdSlot,
    this.impOrtbConfig,
    this.controller,
    this.autoLoad = true,
    this.refreshIntervalSeconds,
    this.videoPlacementType,
    this.listener,
    this.videoListener,
  });

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

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      'configId': widget.configId,
      'width': widget.width,
      'height': widget.height,
      'isVideo': widget.isVideo,
      'autoLoad': widget.autoLoad,
      if (widget.refreshIntervalSeconds != null)
        'refreshIntervalSeconds': widget.refreshIntervalSeconds,
      if (widget.adFormats != null)
        'adFormats': widget.adFormats!.map((f) => f.name).toList(),
      if (widget.pbAdSlot != null) 'pbAdSlot': widget.pbAdSlot,
      if (widget.impOrtbConfig != null) 'impOrtbConfig': widget.impOrtbConfig,
      if (widget.videoPlacementType != null)
        'videoPlacementType': widget.videoPlacementType!.name,
    };

    // The slot sizes dynamically: it starts at the requested size and adopts
    // the actual rendered creative size once the native SDK reports it.
    return SizedBox(
      width: _width,
      height: _height,
      child: _buildPlatformView(creationParams),
    );
  }

  Widget _buildPlatformView(Map<String, dynamic> creationParams) {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidView(
        viewType: 'prebid_mobile_flutter/banner_ad',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      return UiKitView(
        viewType: 'prebid_mobile_flutter/banner_ad',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
    return const SizedBox.shrink();
  }

  void _onPlatformViewCreated(int viewId) {
    // The channel is set up even without a listener so the slot can still
    // resize to the rendered creative via `onAdSize`.
    final channel = MethodChannel('prebid_mobile_flutter/banner_ad_$viewId');
    _channel = channel;
    widget.controller?.attachChannel(channel);
    channel.setMethodCallHandler((call) async {
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
    });
  }

  MethodChannel? _channel;

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      channel.setMethodCallHandler(null);
      widget.controller?.detachChannel(channel);
    }
    super.dispose();
  }
}
