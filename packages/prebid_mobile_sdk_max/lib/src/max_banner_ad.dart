import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidBannerAdListener;

/// A banner ad mediated by **AppLovin MAX** with Prebid demand.
///
/// Prebid runs the auction via a `MediationBannerAdUnit` and passes the winning
/// bid to MAX through the Prebid MAX adapter; MAX then renders either the Prebid
/// creative or a competing MAX creative. Contrast with the core
/// `PrebidBannerAd`, where the Prebid SDK renders directly.
class PrebidMaxBannerAd extends StatefulWidget {
  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AppLovin MAX ad unit ID.
  final String maxAdUnitId;

  /// The desired width of the banner ad in dp.
  final int width;

  /// The desired height of the banner ad in dp.
  final int height;

  /// Whether the ad should load automatically when the widget is created.
  final bool autoLoad;

  /// Listener for banner ad events.
  final PrebidBannerAdListener? listener;

  /// Creates a [PrebidMaxBannerAd] widget.
  const PrebidMaxBannerAd({
    super.key,
    required this.configId,
    required this.maxAdUnitId,
    required this.width,
    required this.height,
    this.autoLoad = true,
    this.listener,
  });

  @override
  State<PrebidMaxBannerAd> createState() => _PrebidMaxBannerAdState();
}

class _PrebidMaxBannerAdState extends State<PrebidMaxBannerAd> {
  /// Current slot size. Starts at the requested size and adopts the actual
  /// rendered creative size once the native SDK reports it via `onAdSize`.
  late double _width = widget.width.toDouble();
  late double _height = widget.height.toDouble();

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      'configId': widget.configId,
      'maxAdUnitId': widget.maxAdUnitId,
      'width': widget.width,
      'height': widget.height,
      'autoLoad': widget.autoLoad,
    };

    return SizedBox(
      width: _width,
      height: _height,
      child: _buildPlatformView(creationParams),
    );
  }

  Widget _buildPlatformView(Map<String, dynamic> creationParams) {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidView(
        viewType: 'prebid_mobile_sdk_max/banner',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      return UiKitView(
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
      }
    });
  }
}
