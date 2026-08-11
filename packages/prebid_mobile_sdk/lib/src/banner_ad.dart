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
  /// Current slot size. Starts at the requested size and is updated to the
  /// actual rendered creative size once the native SDK reports it, so a won
  /// creative larger than the request (e.g. a multisize banner) is not clipped
  /// or overflowed.
  late double _width = widget.width.toDouble();
  late double _height = widget.height.toDouble();

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

    // The slot sizes dynamically: it starts at the requested size and adopts
    // the actual rendered creative size once the native SDK reports it.
    return SizedBox(
      width: _width,
      height: _height,
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
    // The channel is set up even without a listener so the slot can still
    // resize to the rendered creative via `onAdSize`.
    final channel = MethodChannel('prebid_mobile_flutter/banner_ad_$viewId');
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
