import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidAdPosition, PrebidBannerAdController, PrebidBannerAdListener;

import 'admob_testing.dart';

/// A banner ad mediated by **Google AdMob** with Prebid demand.
///
/// Prebid runs the auction via a `MediationBannerAdUnit` and passes the winning
/// bid to AdMob through the Prebid AdMob adapter; AdMob then renders either the
/// Prebid creative or a competing AdMob creative. Contrast with the core
/// `PrebidBannerAd`, where the Prebid SDK renders directly.
class PrebidAdMobBannerAd extends StatefulWidget {
  /// Creates a [PrebidAdMobBannerAd] widget.
  const PrebidAdMobBannerAd({
    super.key,
    required this.configId,
    required this.adMobAdUnitId,
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

  /// Listener for banner ad events.
  final PrebidBannerAdListener? listener;

  @override
  State<PrebidAdMobBannerAd> createState() => _PrebidAdMobBannerAdState();
}

class _PrebidAdMobBannerAdState extends State<PrebidAdMobBannerAd> {
  /// Current slot size. Starts at the requested size and adopts the actual
  /// rendered creative size once the native SDK reports it via `onAdSize`.
  late double _width = widget.width.toDouble();
  late double _height = widget.height.toDouble();

  /// Width available to an [PrebidAdMobBannerAd.adaptive] banner, measured at
  /// its first layout.
  double? _adaptiveWidth;

  /// [PrebidAdMob.debugDropBidProbability] as read when the view was created.
  Map<String, Object> _debugArgs = debugDropBidArgs();

  @override
  void didUpdateWidget(PrebidAdMobBannerAd oldWidget) {
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
    PrebidAdMobBannerAd widget, {
    double? adaptiveWidth,
  }) {
    return <String, dynamic>{
      'configId': widget.configId,
      'adMobAdUnitId': widget.adMobAdUnitId,
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

  @override
  Widget build(BuildContext context) {
    if (!widget.adaptive) {
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
        viewType: 'prebid_mobile_sdk_admob/banner',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        key: key,
        viewType: 'prebid_mobile_sdk_admob/banner',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
    return const SizedBox.shrink();
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('prebid_mobile_sdk_admob/banner_$viewId');
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
