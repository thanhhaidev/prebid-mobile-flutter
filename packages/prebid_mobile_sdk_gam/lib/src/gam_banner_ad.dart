import 'package:flutter/foundation.dart';
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

class _PrebidGamBannerAdState extends State<PrebidGamBannerAd> {
  /// Current slot size. Starts at the requested size and adopts the actual
  /// rendered creative size once the native SDK reports it via `onAdSize`.
  late double _width = widget.width.toDouble();
  late double _height = widget.height.toDouble();

  /// The current native view's channel; a config change gets a new one (and
  /// a new view), so late events from the old view never reach this widget.
  late AdViewChannel _view = _newView();

  /// Whether [_view]'s platform view exists, so its channel can take
  /// [PrebidBannerAdController] calls.
  bool _viewCreated = false;

  AdViewChannel _newView() =>
      AdViewChannel('prebid_mobile_sdk_gam/banner', _onCall);

  @override
  void didUpdateWidget(PrebidGamBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_creationParams(oldWidget).toString() !=
        _creationParams(widget).toString()) {
      // The native view reads its configuration once, so a changed config
      // gets a new view (keyed below) that starts at the requested size.
      _width = widget.width.toDouble();
      _height = widget.height.toDouble();
      _releaseView(oldWidget.controller);
      _view = _newView();
      return;
    }
    if (_viewCreated && !identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.detachChannel(_view.methodChannel);
      widget.controller?.attachChannel(
        _view.methodChannel,
        autoLoaded: widget.autoLoad,
      );
    }
  }

  static Map<String, dynamic> _creationParams(PrebidGamBannerAd widget) {
    return <String, dynamic>{
      'configId': widget.configId,
      'gamAdUnitId': widget.gamAdUnitId,
      'width': widget.width,
      'height': widget.height,
      'isVideo': widget.isVideo,
      'autoLoad': widget.autoLoad,
      if (widget.adPosition != null) 'adPosition': widget.adPosition!.value,
      if (widget.additionalSizes != null)
        'additionalSizes': [
          for (final size in widget.additionalSizes!) ...[
            size.width.round(),
            size.height.round(),
          ],
        ],
      if (widget.adFormats != null)
        'adFormats': widget.adFormats!.map((f) => f.name).toList(),
      if (widget.pbAdSlot != null) 'pbAdSlot': widget.pbAdSlot,
      if (widget.impOrtbConfig != null) 'impOrtbConfig': widget.impOrtbConfig,
      if (widget.globalOrtbConfig != null)
        'globalOrtbConfig': widget.globalOrtbConfig,
      if (widget.videoParameters != null)
        'videoParameters': widget.videoParameters!.toMap(),
      if (widget.refreshIntervalSeconds != null)
        'refreshIntervalSeconds': widget.refreshIntervalSeconds,
      if (widget.customTargeting != null)
        'customTargeting': widget.customTargeting,
      if (widget.videoPlacementType != null)
        'videoPlacementType': widget.videoPlacementType!.name,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: _buildPlatformView(),
    );
  }

  Widget _buildPlatformView() {
    final view = _view;
    final creationParams = {..._creationParams(widget), 'channelId': view.id};
    // A new channel means a new native view (the config changed).
    final key = ValueKey(view.id);
    void onCreated(int _) => _onViewCreated(view);
    // defaultTargetPlatform (not dart:io) so widget tests can pick a platform.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        key: key,
        viewType: 'prebid_mobile_sdk_gam/banner',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: onCreated,
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        key: key,
        viewType: 'prebid_mobile_sdk_gam/banner',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: onCreated,
      );
    }
    return const SizedBox.shrink();
  }

  void _onViewCreated(AdViewChannel view) {
    // A replaced view finishing its creation late has nothing to attach.
    if (!identical(view, _view) || !mounted) return;
    _viewCreated = true;
    widget.controller?.attachChannel(
      view.methodChannel,
      autoLoaded: widget.autoLoad,
    );
  }

  Future<dynamic> _onCall(MethodCall call) async {
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
  }

  void _releaseView(PrebidBannerAdController? controller) {
    _view.dispose();
    if (_viewCreated) controller?.detachChannel(_view.methodChannel);
    _viewCreated = false;
  }

  @override
  void dispose() {
    _releaseView(widget.controller);
    super.dispose();
  }
}
