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

import 'max_listeners.dart';

/// Listener for [PrebidMaxNativeAd] events.
class PrebidMaxNativeAdListener {
  /// Creates a [PrebidMaxNativeAdListener].
  const PrebidMaxNativeAdListener({
    this.onAdLoaded,
    this.onAdImpression,
    this.onAdClicked,
    this.onAdFailed,
    this.onAdRevenuePaid,
  });

  /// The native ad loaded and is rendered.
  final VoidCallback? onAdLoaded;

  /// MAX recorded an impression (reported through its revenue callback).
  final VoidCallback? onAdImpression;

  /// The native ad was clicked.
  final VoidCallback? onAdClicked;

  /// The native ad failed to load.
  final void Function(String error)? onAdFailed;

  /// MAX paid revenue for an impression (it also fires [onAdImpression]).
  final void Function(PrebidMaxAdRevenue revenue)? onAdRevenuePaid;
}

/// A native ad mediated by **AppLovin MAX** with Prebid demand.
///
/// Native ads return unbundled assets (headline, body, icon, image, CTA) that
/// must be rendered through the MAX native ad view for impressions/clicks to
/// register — so this widget hosts a native `MaxNativeAdView` (a PlatformView)
/// that the plugin populates. Prebid's `MediationNativeAdUnit` runs the auction
/// and hands the winning bid to MAX via the Prebid native adapter.
class PrebidMaxNativeAd extends StatefulWidget {
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

  @override
  State<PrebidMaxNativeAd> createState() => _PrebidMaxNativeAdState();
}

class _PrebidMaxNativeAdState extends State<PrebidMaxNativeAd> {
  static const _viewType = 'prebid_mobile_sdk_max/native';

  late double _height = widget.height;

  /// The current native view's channel; a new view gets a new one.
  late AdViewChannel _viewChannel = AdViewChannel(_viewType, _onCall);

  @override
  void didUpdateWidget(PrebidMaxNativeAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_creationParams(oldWidget).toString() !=
        _creationParams(widget).toString()) {
      // The native view reads its configuration once, so a changed config
      // gets a new view (keyed by its channel below) that starts at the
      // requested height.
      _height = widget.height;
      _viewChannel.dispose();
      _viewChannel = AdViewChannel(_viewType, _onCall);
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
    return SizedBox(
      width: double.infinity,
      height: _height,
      child: _buildPlatformView(),
    );
  }

  Widget _buildPlatformView() {
    final channel = _viewChannel;
    final creationParams = {
      ..._creationParams(widget),
      'channelId': channel.id,
    };
    // Each view has its own channel, so the channel id keys the view.
    final key = ValueKey(channel.id);
    // defaultTargetPlatform (not dart:io) so widget tests can pick a platform.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        key: key,
        viewType: _viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        key: key,
        viewType: _viewType,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return const SizedBox.shrink();
  }

  Future<dynamic> _onCall(MethodCall call) async {
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
      case 'onAdRevenuePaid':
        widget.listener?.onAdRevenuePaid?.call(
          maxAdRevenueFrom(call.arguments as Map?),
        );
    }
  }

  @override
  void dispose() {
    _viewChannel.dispose();
    super.dispose();
  }
}
