import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/companion.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show
        NativeAsset,
        NativeContextSubType,
        NativeContextType,
        NativeEventTracker,
        NativePlacementType;

/// Listener for [PrebidAdMobNativeAd] events, mirroring the AdMob native
/// callback set from Prebid's reference integration.
class PrebidAdMobNativeAdListener {
  /// Creates a [PrebidAdMobNativeAdListener].
  const PrebidAdMobNativeAdListener({
    this.onAdLoaded,
    this.onAdImpression,
    this.onAdClicked,
    this.onAdOpened,
    this.onAdFailed,
  });

  /// The native ad loaded and is rendered.
  final VoidCallback? onAdLoaded;

  /// An impression was recorded.
  final VoidCallback? onAdImpression;

  /// The native ad was clicked.
  final VoidCallback? onAdClicked;

  /// The native ad opened an overlay / left the app.
  final VoidCallback? onAdOpened;

  /// The native ad failed to load.
  final void Function(String error)? onAdFailed;
}

/// A native ad mediated by **Google AdMob** with Prebid demand.
///
/// Native ads return unbundled assets (headline, body, icon, media, CTA) that
/// must be rendered through the AdMob native ad view for impressions/clicks to
/// register — so this widget hosts a native `NativeAdView` (a PlatformView)
/// that the plugin populates. Prebid's `MediationNativeAdUnit` runs the auction
/// and hands the winning bid to AdMob via the Prebid native adapter.
///
/// On Android a native ad created before the Prebid SDK finished initializing
/// reports `onAdFailed` ("The Prebid SDK is not initialized"): Prebid Android
/// drops such requests, so AdMob's waterfall would never run.
class PrebidAdMobNativeAd extends StatefulWidget {
  /// Creates a [PrebidAdMobNativeAd] widget.
  const PrebidAdMobNativeAd({
    super.key,
    required this.configId,
    required this.adMobAdUnitId,
    this.height = 320,
    this.assets,
    this.eventTrackers,
    this.context,
    this.contextSubType,
    this.placementType,
    this.listener,
  });

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AdMob native ad unit ID.
  final String adMobAdUnitId;

  /// Height of the native ad slot in dp. Grows to the rendered content when the
  /// native layout reports its measured height.
  final double height;

  /// Native assets to request. `null` requests Prebid's reference set
  /// (title, icon, sponsored, description, call to action).
  final List<NativeAsset>? assets;

  /// Native event trackers. `null` requests impression trackers (image + JS).
  final List<NativeEventTracker>? eventTrackers;

  /// Native context, context subtype and placement type. Default: social
  /// context, general-social subtype, in-feed placement.
  final NativeContextType? context;

  /// Native context subtype (`contextsubtype`).
  final NativeContextSubType? contextSubType;

  /// Native placement type (`plcmttype`).
  final NativePlacementType? placementType;

  /// Listener for native ad events.
  final PrebidAdMobNativeAdListener? listener;

  @override
  State<PrebidAdMobNativeAd> createState() => _PrebidAdMobNativeAdState();
}

class _PrebidAdMobNativeAdState extends State<PrebidAdMobNativeAd> {
  late double _height = widget.height;

  /// The current native view's channel. Each view gets its own, so events of
  /// a replaced view can't reach this widget.
  late AdViewChannel _view = _newView();

  AdViewChannel _newView() =>
      AdViewChannel('prebid_mobile_sdk_admob/native', _onCall);

  @override
  void didUpdateWidget(PrebidAdMobNativeAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_creationParams(oldWidget).toString() !=
        _creationParams(widget).toString()) {
      // The native view reads its configuration once, so a changed config
      // gets a new view (keyed by its channel) that starts at the requested
      // height.
      _height = widget.height;
      _view.dispose();
      _view = _newView();
    }
  }

  static Map<String, dynamic> _creationParams(PrebidAdMobNativeAd widget) {
    return <String, dynamic>{
      'configId': widget.configId,
      'adMobAdUnitId': widget.adMobAdUnitId,
      if (widget.assets != null)
        'assets': widget.assets!.map((a) => a.toMap()).toList(),
      if (widget.eventTrackers != null)
        'eventTrackers': widget.eventTrackers!.map((t) => t.toMap()).toList(),
      if (widget.context != null) 'context': widget.context!.value,
      if (widget.contextSubType != null)
        'contextSubType': widget.contextSubType!.value,
      if (widget.placementType != null)
        'placementType': widget.placementType!.value,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _height,
      child: _buildPlatformView(),
    );
  }

  Widget _buildPlatformView() {
    final creationParams = {..._creationParams(widget), 'channelId': _view.id};
    // A new channel means a new native view (the config changed).
    final key = ValueKey(_view.id);
    // defaultTargetPlatform (not dart:io) so widget tests can pick a platform.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        key: key,
        viewType: 'prebid_mobile_sdk_admob/native',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        key: key,
        viewType: 'prebid_mobile_sdk_admob/native',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return const SizedBox.shrink();
  }

  Future<dynamic> _onCall(MethodCall call) async {
    final l = widget.listener;
    switch (call.method) {
      case 'onAdSize':
        final h = ((call.arguments as Map?)?['height'] as num?)?.toDouble();
        if (h != null && h > 0 && mounted) setState(() => _height = h);
      case 'onAdLoaded':
        l?.onAdLoaded?.call();
      case 'onAdImpression':
        l?.onAdImpression?.call();
      case 'onAdClicked':
        l?.onAdClicked?.call();
      case 'onAdOpened':
        l?.onAdOpened?.call();
      case 'onAdFailed':
        l?.onAdFailed?.call(call.arguments as String? ?? '');
    }
  }

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }
}
