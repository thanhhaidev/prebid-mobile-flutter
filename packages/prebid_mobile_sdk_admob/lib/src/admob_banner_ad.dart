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

  /// The current native view's channel. Each view gets its own, so events of
  /// a replaced view can't reach this widget.
  late AdViewChannel _view = _newView();

  /// Whether the native view of [_view] exists, so the controller can talk
  /// to it.
  bool _viewCreated = false;

  AdViewChannel _newView() =>
      AdViewChannel('prebid_mobile_sdk_admob/banner', _onCall);

  @override
  void didUpdateWidget(PrebidAdMobBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_creationParams(oldWidget).toString() !=
        _creationParams(widget).toString()) {
      // The native view reads its configuration once, so a changed config
      // gets a new view (keyed by its channel) that starts at the requested
      // size. The old channel is dropped now, so a `controller.loadAd()` made
      // before the new view exists is queued and replayed on it.
      _width = widget.width.toDouble();
      _height = widget.height.toDouble();
      _adaptiveWidth = null;
      _debugArgs = debugDropBidArgs();
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

  static Map<String, dynamic> _creationParams(PrebidAdMobBannerAd widget) {
    return <String, dynamic>{
      'configId': widget.configId,
      'adMobAdUnitId': widget.adMobAdUnitId,
      'width': widget.width,
      'height': widget.height,
      'autoLoad': widget.autoLoad,
      if (widget.adPosition != null) 'adPosition': widget.adPosition!.value,
      if (widget.impOrtbConfig != null) 'impOrtbConfig': widget.impOrtbConfig,
      if (widget.globalOrtbConfig != null)
        'globalOrtbConfig': widget.globalOrtbConfig,
      if (widget.pbAdSlot != null) 'pbAdSlot': widget.pbAdSlot,
      if (widget.additionalSizes != null)
        'additionalSizes': [
          for (final size in widget.additionalSizes!) ...[
            size.width.round(),
            size.height.round(),
          ],
        ],
      if (widget.adFormats != null)
        'adFormats': widget.adFormats!.map((f) => f.name).toList(),
      if (widget.videoParameters != null)
        'videoParameters': widget.videoParameters!.toMap(),
      if (widget.adaptive) 'adaptive': true,
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
            ..._creationParams(widget),
            'adaptiveWidth': width.round(),
            ..._debugArgs,
          }),
        );
      },
    );
  }

  Widget _buildPlatformView(Map<String, dynamic> params) {
    final view = _view;
    final creationParams = {...params, 'channelId': view.id};
    // A new channel means a new native view (the config changed).
    final key = ValueKey(view.id);
    void onCreated(int _) => _onViewCreated(view);
    // defaultTargetPlatform (not dart:io) so widget tests can pick a platform.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        key: key,
        viewType: 'prebid_mobile_sdk_admob/banner',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: onCreated,
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        key: key,
        viewType: 'prebid_mobile_sdk_admob/banner',
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
      case 'onAdImpression':
        widget.listener?.onAdImpression?.call();
      case 'onAdClosed':
        widget.listener?.onAdClosed?.call();
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
