import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidAdPosition, PrebidBannerAdController, PrebidBannerAdListener;

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
    this.refreshIntervalSeconds,
    this.autoLoad = true,
    this.controller,
    this.adPosition,
    this.impOrtbConfig,
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

  /// Listener for banner ad events. Pass a [PrebidMaxBannerAdListener] to
  /// also get MAX's expand / collapse, display-failure and revenue events.
  final PrebidBannerAdListener? listener;

  @override
  State<PrebidMaxBannerAd> createState() => _PrebidMaxBannerAdState();
}

class _PrebidMaxBannerAdState extends State<PrebidMaxBannerAd> {
  /// Current slot size. Starts at the requested size and adopts the actual
  /// rendered creative size once the native SDK reports it via `onAdSize`.
  late double _width = widget.width.toDouble();
  late double _height = widget.height.toDouble();

  /// Width available to an [PrebidMaxBannerAd.adaptive] banner, measured at
  /// its first layout.
  double? _adaptiveWidth;

  /// [PrebidMax.debugDropBidProbability] as read when the view was created.
  Map<String, Object> _debugArgs = debugDropBidArgs();

  @override
  void didUpdateWidget(PrebidMaxBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    final channel = _channel;
    if (channel != null &&
        !identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.detachChannel(channel);
      widget.controller?.attachChannel(channel, autoLoaded: widget.autoLoad);
    }
    if (_creationParams(oldWidget).toString() !=
        _creationParams(widget).toString()) {
      // The native view reads its configuration once, so a changed config
      // gets a new view (keyed below) that starts at the requested size.
      _width = widget.width.toDouble();
      _height = widget.height.toDouble();
      _adaptiveWidth = null;
      _debugArgs = debugDropBidArgs();
    }
  }

  static Map<String, dynamic> _creationParams(
    PrebidMaxBannerAd widget, {
    double? adaptiveWidth,
  }) {
    return <String, dynamic>{
      'configId': widget.configId,
      'maxAdUnitId': widget.maxAdUnitId,
      'width': widget.width,
      'height': widget.height,
      'autoLoad': widget.autoLoad,
      if (widget.adPosition != null) 'adPosition': widget.adPosition!.value,
      if (widget.impOrtbConfig != null) 'impOrtbConfig': widget.impOrtbConfig,
      if (widget.additionalSizes != null)
        'additionalSizes': [
          for (final size in widget.additionalSizes!) ...[
            size.width.round(),
            size.height.round(),
          ],
        ],
      if (widget.adaptive) 'adaptive': true,
      if (adaptiveWidth != null) 'adaptiveWidth': adaptiveWidth.round(),
      if (widget.refreshIntervalSeconds != null)
        'refreshIntervalSeconds': widget.refreshIntervalSeconds,
    };
  }

  /// MREC banners keep their fixed size: MAX adaptive banners are banner-only.
  bool get _isAdaptive =>
      widget.adaptive && !(widget.width == 300 && widget.height == 250);

  @override
  Widget build(BuildContext context) {
    if (!_isAdaptive) {
      return SizedBox(
        width: _width,
        height: _height,
        child: _buildPlatformView({..._creationParams(widget), ..._debugArgs}),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _adaptiveWidth ??= constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return SizedBox(
          width: width,
          height: _height,
          child: _buildPlatformView({
            ..._creationParams(widget, adaptiveWidth: width),
            ..._debugArgs,
          }),
        );
      },
    );
  }

  Widget _buildPlatformView(Map<String, dynamic> creationParams) {
    // Recreate the native view when its configuration changes.
    final key = ValueKey(creationParams.toString());
    // defaultTargetPlatform (not dart:io) so widget tests can pick a platform.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        key: key,
        viewType: 'prebid_mobile_sdk_max/banner',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        key: key,
        viewType: 'prebid_mobile_sdk_max/banner',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
    return const SizedBox.shrink();
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('prebid_mobile_sdk_max/banner_$viewId');
    final previous = _channel;
    if (previous != null) {
      previous.setMethodCallHandler(null);
      widget.controller?.detachChannel(previous);
    }
    _channel = channel;
    widget.controller?.attachChannel(channel, autoLoaded: widget.autoLoad);
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
        case 'onAdImpression':
          widget.listener?.onAdImpression?.call();
        case 'onAdClosed':
          widget.listener?.onAdClosed?.call();
        case 'onAdDisplayFailed':
          final error = call.arguments as String? ?? '';
          widget.listener?.onAdFailed?.call(error);
          _maxListener?.onAdDisplayFailed?.call(error);
        case 'onAdExpanded':
          _maxListener?.onAdExpanded?.call();
        case 'onAdCollapsed':
          _maxListener?.onAdCollapsed?.call();
        case 'onAdRevenuePaid':
          _maxListener?.onAdRevenuePaid?.call(
            maxAdRevenueFrom(call.arguments as Map?),
          );
      }
    });
  }

  MethodChannel? _channel;

  PrebidMaxBannerAdListener? get _maxListener {
    final listener = widget.listener;
    return listener is PrebidMaxBannerAdListener ? listener : null;
  }

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
