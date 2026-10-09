import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show
        NativeAsset,
        NativeContextSubType,
        NativeContextType,
        NativeEventTracker,
        NativePlacementType;

/// Listener for [PrebidMaxNativeAd] events.
class PrebidMaxNativeAdListener {
  /// The native ad loaded and is rendered.
  final VoidCallback? onAdLoaded;

  /// MAX recorded an impression (reported through its revenue callback).
  final VoidCallback? onAdImpression;

  /// The native ad was clicked.
  final VoidCallback? onAdClicked;

  /// The native ad failed to load.
  final void Function(String error)? onAdFailed;

  /// Creates a [PrebidMaxNativeAdListener].
  const PrebidMaxNativeAdListener({
    this.onAdLoaded,
    this.onAdImpression,
    this.onAdClicked,
    this.onAdFailed,
  });
}

/// A native ad mediated by **AppLovin MAX** with Prebid demand.
///
/// Native ads return unbundled assets (headline, body, icon, image, CTA) that
/// must be rendered through the MAX native ad view for impressions/clicks to
/// register — so this widget hosts a native `MaxNativeAdView` (a PlatformView)
/// that the plugin populates. Prebid's `MediationNativeAdUnit` runs the auction
/// and hands the winning bid to MAX via the Prebid native adapter.
class PrebidMaxNativeAd extends StatefulWidget {
  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AppLovin MAX native ad unit ID.
  final String maxAdUnitId;

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
  final PrebidMaxNativeAdListener? listener;

  /// Creates a [PrebidMaxNativeAd] widget.
  const PrebidMaxNativeAd({
    super.key,
    required this.configId,
    required this.maxAdUnitId,
    this.height = 320,
    this.assets,
    this.eventTrackers,
    this.context,
    this.contextSubType,
    this.placementType,
    this.listener,
  });

  @override
  State<PrebidMaxNativeAd> createState() => _PrebidMaxNativeAdState();
}

class _PrebidMaxNativeAdState extends State<PrebidMaxNativeAd> {
  late double _height = widget.height;

  @override
  void didUpdateWidget(PrebidMaxNativeAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_creationParams(oldWidget).toString() !=
        _creationParams(widget).toString()) {
      // The native view reads its configuration once, so a changed config
      // gets a new view (keyed below) that starts at the requested height.
      _height = widget.height;
    }
  }

  static Map<String, dynamic> _creationParams(PrebidMaxNativeAd widget) {
    return <String, dynamic>{
      'configId': widget.configId,
      'maxAdUnitId': widget.maxAdUnitId,
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
    final creationParams = _creationParams(widget);

    return SizedBox(
      width: double.infinity,
      height: _height,
      child: _buildPlatformView(creationParams),
    );
  }

  Widget _buildPlatformView(Map<String, dynamic> creationParams) {
    // Recreate the native view when its configuration changes.
    final key = ValueKey(creationParams.toString());
    // defaultTargetPlatform (not dart:io) so widget tests can pick a platform.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        key: key,
        viewType: 'prebid_mobile_sdk_max/native',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onCreated,
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        key: key,
        viewType: 'prebid_mobile_sdk_max/native',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onCreated,
      );
    }
    return const SizedBox.shrink();
  }

  void _onCreated(int viewId) {
    final channel = MethodChannel('prebid_mobile_sdk_max/native_$viewId');
    // A re-created view (changed config) replaces the previous one: stop
    // listening to the old view's channel.
    _channel?.setMethodCallHandler(null);
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAdSize':
          final h = ((call.arguments as Map?)?['height'] as num?)?.toDouble();
          if (h != null && h > 0 && mounted) setState(() => _height = h);
        case 'onAdLoaded':
          widget.listener?.onAdLoaded?.call();
        case 'onAdFailed':
          widget.listener?.onAdFailed?.call(call.arguments as String? ?? '');
        case 'onAdClicked':
          widget.listener?.onAdClicked?.call();
        case 'onAdImpression':
          widget.listener?.onAdImpression?.call();
      }
    });
  }

  MethodChannel? _channel;

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }
}
