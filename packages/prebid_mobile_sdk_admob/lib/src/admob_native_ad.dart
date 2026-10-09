import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Listener for [PrebidAdMobNativeAd] events, mirroring the AdMob native
/// callback set from Prebid's reference integration.
class PrebidAdMobNativeAdListener {
  /// The native ad loaded and is rendered.
  final VoidCallback? onAdLoaded;

  /// An impression was recorded.
  final VoidCallback? onAdImpression;

  /// The native ad was clicked.
  final VoidCallback? onAdClicked;

  /// The native ad opened an overlay / left the app.
  final VoidCallback? onAdOpened;

  /// The native ad failed to load.
  final void Function(String error)? onAdFailed;

  /// Creates a [PrebidAdMobNativeAdListener].
  const PrebidAdMobNativeAdListener({
    this.onAdLoaded,
    this.onAdImpression,
    this.onAdClicked,
    this.onAdOpened,
    this.onAdFailed,
  });
}

/// A native ad mediated by **Google AdMob** with Prebid demand.
///
/// Native ads return unbundled assets (headline, body, icon, media, CTA) that
/// must be rendered through the AdMob native ad view for impressions/clicks to
/// register — so this widget hosts a native `NativeAdView` (a PlatformView)
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

  /// Listener for native ad events.
  final PrebidAdMobNativeAdListener? listener;

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
    final l = widget.listener;
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAdSize':
          final h = ((call.arguments as Map?)?['height'] as num?)?.toDouble();
          if (h != null && h > 0 && mounted) setState(() => _height = h);
        case 'onAdLoaded':
          l?.onAdLoaded?.call();
        case 'onAdImpression':
          l?.onAdImpression?.call();
        case 'onAdClicked':
          l?.onAdClicked?.call();
        case 'onAdOpened':
          l?.onAdOpened?.call();
        case 'onAdFailed':
          l?.onAdFailed?.call(call.arguments as String? ?? '');
      }
    });
  }
}
