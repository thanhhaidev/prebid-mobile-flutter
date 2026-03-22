import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'ad_listener.dart';

/// A banner ad widget that displays a Prebid rendered banner.
///
/// Uses a native PlatformView to render the banner ad on both Android and iOS.
class PrebidBannerAd extends StatefulWidget {
  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The desired width of the banner ad in dp.
  final int width;

  /// The desired height of the banner ad in dp.
  final int height;

  /// Whether this banner should display video ads.
  final bool isVideo;

  /// Whether the ad should load automatically when the widget is created.
  final bool autoLoad;

  /// Auto-refresh interval in seconds.
  ///
  /// If set, the banner will automatically request new ads at this interval.
  /// Minimum recommended value is `30` seconds.
  /// Set to `null` (default) to disable auto-refresh.
  final int? refreshIntervalSeconds;

  /// Listener for banner ad events.
  final PrebidBannerAdListener? listener;

  /// Creates a [PrebidBannerAd] widget.
  const PrebidBannerAd({
    super.key,
    required this.configId,
    required this.width,
    required this.height,
    this.isVideo = false,
    this.autoLoad = true,
    this.refreshIntervalSeconds,
    this.listener,
  });

  @override
  State<PrebidBannerAd> createState() => _PrebidBannerAdState();
}

class _PrebidBannerAdState extends State<PrebidBannerAd> {
  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      'configId': widget.configId,
      'width': widget.width,
      'height': widget.height,
      'isVideo': widget.isVideo,
      'autoLoad': widget.autoLoad,
      if (widget.refreshIntervalSeconds != null)
        'refreshIntervalSeconds': widget.refreshIntervalSeconds,
    };

    return SizedBox(
      width: widget.width.toDouble(),
      height: widget.height.toDouble(),
      child: _buildPlatformView(creationParams),
    );
  }

  Widget _buildPlatformView(Map<String, dynamic> creationParams) {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidView(
        viewType: 'prebid_mobile_flutter/banner_ad',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      return UiKitView(
        viewType: 'prebid_mobile_flutter/banner_ad',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
    return const SizedBox.shrink();
  }

  void _onPlatformViewCreated(int viewId) {
    if (widget.listener == null) return;

    final channel = MethodChannel('prebid_mobile_flutter/banner_ad_$viewId');
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAdLoaded':
          widget.listener?.onAdLoaded?.call();
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
