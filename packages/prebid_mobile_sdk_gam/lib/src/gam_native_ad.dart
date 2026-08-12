import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

/// A native ad rendered by Google Ad Manager after an Original API native
/// Prebid demand fetch.
class PrebidGamNativeAd extends StatefulWidget {
  /// The Prebid Server stored impression config ID.
  final String configId;

  /// The Google Ad Manager native ad unit ID.
  final String gamAdUnitId;

  /// Width of the native view.
  final double width;

  /// Initial height of the native view.
  final double height;

  /// Native assets to request from Prebid.
  final List<NativeAsset> assets;

  /// Native event trackers to request from Prebid.
  final List<NativeEventTracker>? eventTrackers;

  /// Listener for native ad events.
  final PrebidNativeAdListener? listener;

  const PrebidGamNativeAd({
    super.key,
    required this.configId,
    required this.gamAdUnitId,
    this.width = double.infinity,
    this.height = 320,
    this.assets = const [
      NativeAsset.title(length: 90, required: true),
      NativeAsset.image(
        imageType: NativeImageType.icon,
        widthMin: 20,
        heightMin: 20,
        required: true,
      ),
      NativeAsset.image(
        imageType: NativeImageType.main,
        widthMin: 200,
        heightMin: 200,
        required: true,
      ),
      NativeAsset.data(dataType: NativeDataType.sponsored, required: true),
      NativeAsset.data(dataType: NativeDataType.desc, required: true),
      NativeAsset.data(dataType: NativeDataType.ctaText, required: true),
    ],
    this.eventTrackers,
    this.listener,
  });

  @override
  State<PrebidGamNativeAd> createState() => _PrebidGamNativeAdState();
}

class _PrebidGamNativeAdState extends State<PrebidGamNativeAd> {
  static int _nextViewId = 7000000;

  late final int _logicalId = _nextViewId++;
  late final MethodChannel _channel;
  PrebidNativeAdUnit? _adUnit;
  Map<String, String>? _targeting;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _channel = MethodChannel('prebid_mobile_sdk_gam/native_$_logicalId')
      ..setMethodCallHandler(_onNativeEvent);
    _loadDemand();
  }

  Future<void> _loadDemand() async {
    final adUnit = PrebidNativeAdUnit(
      configId: widget.configId,
      assets: widget.assets,
      eventTrackers: widget.eventTrackers,
    );
    _adUnit = adUnit;
    final response = await adUnit.fetchDemand();
    if (!mounted) return;
    if (!response.isSuccess) {
      _failed = true;
      widget.listener?.onAdFailed?.call(response.resultCode);
      setState(() {});
      return;
    }
    setState(() => _targeting = response.targetingKeywords ?? {});
  }

  Future<dynamic> _onNativeEvent(MethodCall call) async {
    switch (call.method) {
      case 'onAdLoaded':
        widget.listener?.onAdLoaded?.call(const PrebidNativeAdResponse());
      case 'onAdFailed':
        widget.listener?.onAdFailed?.call(call.arguments as String? ?? '');
      case 'onAdClicked':
        widget.listener?.onAdClicked?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final targeting = _targeting;
    if (targeting == null) {
      return SizedBox(width: widget.width, height: widget.height);
    }

    final creationParams = <String, Object?>{
      'logicalId': _logicalId,
      'gamAdUnitId': widget.gamAdUnitId,
      'customTargeting': targeting,
    };

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: defaultTargetPlatform == TargetPlatform.iOS
          ? UiKitView(
              viewType: 'prebid_mobile_sdk_gam/native',
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
            )
          : AndroidView(
              viewType: 'prebid_mobile_sdk_gam/native',
              creationParams: creationParams,
              creationParamsCodec: const StandardMessageCodec(),
            ),
    );
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _adUnit?.destroy();
    super.dispose();
  }
}
