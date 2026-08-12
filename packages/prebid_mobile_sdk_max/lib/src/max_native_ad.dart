import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidBannerAdListener;

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

  /// Listener for native ad events (`onAdLoaded` / `onAdFailed` / `onAdClicked`).
  final PrebidBannerAdListener? listener;

  /// Creates a [PrebidMaxNativeAd] widget.
  const PrebidMaxNativeAd({
    super.key,
    required this.configId,
    required this.maxAdUnitId,
    this.height = 320,
    this.listener,
  });

  @override
  State<PrebidMaxNativeAd> createState() => _PrebidMaxNativeAdState();
}

class _PrebidMaxNativeAdState extends State<PrebidMaxNativeAd> {
  late double _height = widget.height;

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      'configId': widget.configId,
      'maxAdUnitId': widget.maxAdUnitId,
    };

    return SizedBox(
      width: double.infinity,
      height: _height,
      child: _buildPlatformView(creationParams),
    );
  }

  Widget _buildPlatformView(Map<String, dynamic> creationParams) {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidView(
        viewType: 'prebid_mobile_sdk_max/native',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onCreated,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      return UiKitView(
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
      }
    });
  }
}
