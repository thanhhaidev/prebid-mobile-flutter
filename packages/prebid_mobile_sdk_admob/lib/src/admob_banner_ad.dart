import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidBannerAdListener;

/// A banner ad mediated by **Google AdMob** with Prebid demand.
///
/// Prebid runs the auction via a `MediationBannerAdUnit` and passes the winning
/// bid to AdMob through the Prebid AdMob adapter; AdMob then renders either the
/// Prebid creative or a competing AdMob creative. Contrast with the core
/// `PrebidBannerAd`, where the Prebid SDK renders directly.
class PrebidAdMobBannerAd extends StatefulWidget {
  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AdMob ad unit ID (e.g. `ca-app-pub-3940256099942544/6300978111`).
  final String adMobAdUnitId;

  /// The desired width of the banner ad in dp.
  final int width;

  /// The desired height of the banner ad in dp.
  final int height;

  /// Whether the ad should load automatically when the widget is created.
  final bool autoLoad;

  /// Listener for banner ad events.
  final PrebidBannerAdListener? listener;

  /// Creates a [PrebidAdMobBannerAd] widget.
  const PrebidAdMobBannerAd({
    super.key,
    required this.configId,
    required this.adMobAdUnitId,
    required this.width,
    required this.height,
    this.autoLoad = true,
    this.listener,
  });

  @override
  State<PrebidAdMobBannerAd> createState() => _PrebidAdMobBannerAdState();
}

class _PrebidAdMobBannerAdState extends State<PrebidAdMobBannerAd> {
  /// Current slot size. Starts at the requested size and adopts the actual
  /// rendered creative size once the native SDK reports it via `onAdSize`.
  late double _width = widget.width.toDouble();
  late double _height = widget.height.toDouble();

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      'configId': widget.configId,
      'adMobAdUnitId': widget.adMobAdUnitId,
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
        viewType: 'prebid_mobile_sdk_admob/banner',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      return UiKitView(
        viewType: 'prebid_mobile_sdk_admob/banner',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
    return const SizedBox.shrink();
  }

  void _onPlatformViewCreated(int viewId) {
    final channel = MethodChannel('prebid_mobile_sdk_admob/banner_$viewId');
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
