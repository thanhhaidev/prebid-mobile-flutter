import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/companion.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart' show NativeParameters;

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
    this.nativeParameters = const NativeParameters(),
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.listener,
  });

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AppLovin MAX native ad unit ID.
  final String maxAdUnitId;

  /// Height of the native ad slot in dp. Grows to the rendered content when the
  /// native layout reports its measured height.
  final double height;

  /// The native request: assets, event trackers, context and options.
  /// Unset assets request Prebid's reference set; unset event trackers request
  /// impression trackers (image + JS); the context, subtype and placement
  /// default to social, general social and in-feed.
  final NativeParameters nativeParameters;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp`.
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only (merged over
  /// `PrebidTargeting.setGlobalOrtbConfig`).
  final String? globalOrtbConfig;

  /// Listener for native ad events.
  final PrebidMaxNativeAdListener? listener;

  @override
  State<PrebidMaxNativeAd> createState() => _PrebidMaxNativeAdState();
}

class _PrebidMaxNativeAdState extends State<PrebidMaxNativeAd>
    with AdViewState<PrebidMaxNativeAd> {
  @override
  String get viewType => 'prebid_mobile_sdk_max/native';

  @override
  Map<String, Object?> configOf(PrebidMaxNativeAd widget) => {
    'configId': widget.configId,
    'maxAdUnitId': widget.maxAdUnitId,
    ...widget.nativeParameters.toMap(),
    'impOrtbConfig': ?widget.impOrtbConfig,
    'globalOrtbConfig': ?widget.globalOrtbConfig,
  };

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: reportedHeight ?? widget.height,
    child: buildAdView(),
  );

  @override
  void onViewEvent(MethodCall call) {
    final l = widget.listener;
    switch (call.method) {
      case 'onAdLoaded':
        l?.onAdLoaded?.call();
      case 'onAdFailed':
        l?.onAdFailed?.call(adEventError(call.arguments));
      case 'onAdClicked':
        l?.onAdClicked?.call();
      case 'onAdImpression':
        l?.onAdImpression?.call();
      case 'onAdRevenuePaid':
        l?.onAdRevenuePaid?.call(maxAdRevenueFrom(call.arguments as Map?));
    }
  }
}
