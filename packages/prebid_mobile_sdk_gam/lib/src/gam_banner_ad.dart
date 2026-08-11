import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidBannerAdListener;

/// A banner ad rendered by **Google Ad Manager** with Prebid demand.
///
/// Prebid runs the auction and, via its GAM event handler, GAM renders either
/// the winning Prebid creative (through a Prebid line item + the Prebid
/// Universal Creative) or a direct-sold GAM ad. Contrast with the core
/// `PrebidBannerAd`, where the Prebid SDK renders directly.
class PrebidGamBannerAd extends StatefulWidget {
  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The Google Ad Manager ad unit ID (e.g. `/1234567/your-ad-unit`).
  final String gamAdUnitId;

  /// The desired width of the banner ad in dp.
  final int width;

  /// The desired height of the banner ad in dp.
  final int height;

  /// Whether this banner should display video ads.
  final bool isVideo;

  /// Whether the ad should load automatically when the widget is created.
  final bool autoLoad;

  /// Auto-refresh interval in seconds. `null` (default) disables auto-refresh.
  final int? refreshIntervalSeconds;

  /// Listener for banner ad events.
  final PrebidBannerAdListener? listener;

  /// Creates a [PrebidGamBannerAd] widget.
  const PrebidGamBannerAd({
    super.key,
    required this.configId,
    required this.gamAdUnitId,
    required this.width,
    required this.height,
    this.isVideo = false,
    this.autoLoad = true,
    this.refreshIntervalSeconds,
    this.listener,
  });

  @override
  State<PrebidGamBannerAd> createState() => _PrebidGamBannerAdState();
}

class _PrebidGamBannerAdState extends State<PrebidGamBannerAd> {
  /// Current slot size. Starts at the requested size and adopts the actual
  /// rendered creative size once the native SDK reports it via `onAdSize`.
  late double _width = widget.width.toDouble();
  late double _height = widget.height.toDouble();

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      'configId': widget.configId,
      'gamAdUnitId': widget.gamAdUnitId,
      'width': widget.width,
      'height': widget.height,
      'isVideo': widget.isVideo,
      'autoLoad': widget.autoLoad,
      if (widget.refreshIntervalSeconds != null)
        'refreshIntervalSeconds': widget.refreshIntervalSeconds,
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
        viewType: 'prebid_mobile_sdk_gam/banner',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      return UiKitView(
        viewType: 'prebid_mobile_sdk_gam/banner',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
    return const SizedBox.shrink();
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('prebid_mobile_sdk_gam/banner_$viewId');
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
