import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidBannerAdListener;

/// A native ad mediated by **Google AdMob** with Prebid demand.
///
/// Native ads return unbundled assets (headline, body, icon, image, CTA) that
/// must be rendered through the AdMob native ad view for impressions/clicks to
/// register — so this widget hosts a native `GADNativeAdView` (a PlatformView)
/// that the plugin populates. Prebid's `MediationNativeAdUnit` runs the auction
/// and hands the winning bid to AdMob via the Prebid native adapter.
class PrebidAdMobNativeAd extends StatefulWidget {
  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AdMob native ad unit ID.
  final String adMobAdUnitId;

  /// Height of the native ad slot in dp. Grows to the rendered content when the
  /// native layout reports its measured height.
  final double height;

  /// Listener for native ad events (`onAdLoaded` / `onAdFailed` / `onAdClicked`).
  final PrebidBannerAdListener? listener;

  /// Creates a [PrebidAdMobNativeAd] widget.
  const PrebidAdMobNativeAd({
    super.key,
    required this.configId,
    required this.adMobAdUnitId,
    this.height = 320,
    this.listener,
  });

  @override
  State<PrebidAdMobNativeAd> createState() => _PrebidAdMobNativeAdState();
}

class _PrebidAdMobNativeAdState extends State<PrebidAdMobNativeAd> {
  late double _height = widget.height;

  @override
  Widget build(BuildContext context) {
    final creationParams = <String, dynamic>{
      'configId': widget.configId,
      'adMobAdUnitId': widget.adMobAdUnitId,
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
        viewType: 'prebid_mobile_sdk_admob/native',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onCreated,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      return UiKitView(
        viewType: 'prebid_mobile_sdk_admob/native',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onCreated,
      );
    }
    return const SizedBox.shrink();
  }

  void _onCreated(int viewId) {
    final channel = MethodChannel('prebid_mobile_sdk_admob/native_$viewId');
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
