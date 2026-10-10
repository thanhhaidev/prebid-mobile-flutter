import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/companion.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart' show NativeParameters;

/// Listener for [PrebidAdMobNativeAd] events, mirroring the AdMob native
/// callback set from Prebid's reference integration.
class PrebidAdMobNativeAdListener {
  /// Creates a [PrebidAdMobNativeAdListener].
  const PrebidAdMobNativeAdListener({
    this.onAdLoaded,
    this.onAdImpression,
    this.onAdClicked,
    this.onAdOpened,
    this.onAdFailed,
  });

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
}

/// A native ad mediated by **Google AdMob** with Prebid demand.
///
/// Native ads return unbundled assets (headline, body, icon, media, CTA) that
/// must be rendered through the AdMob native ad view for impressions/clicks to
/// register — so this widget hosts a native `NativeAdView` (a PlatformView)
/// that the plugin populates. Prebid's `MediationNativeAdUnit` runs the auction
/// and hands the winning bid to AdMob via the Prebid native adapter.
///
/// On Android a native ad created before the Prebid SDK finished initializing
/// reports `onAdFailed` ("The Prebid SDK is not initialized"): Prebid Android
/// drops such requests, so AdMob's waterfall would never run.
class PrebidAdMobNativeAd extends StatefulWidget {
  /// Creates a [PrebidAdMobNativeAd] widget.
  const PrebidAdMobNativeAd({
    super.key,
    required this.configId,
    required this.adMobAdUnitId,
    this.height = 320,
    this.nativeParameters = const NativeParameters(),
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.listener,
  });

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AdMob native ad unit ID.
  final String adMobAdUnitId;

  /// Height of the native ad slot in dp. Grows to the rendered content when the
  /// native layout reports its measured height.
  final double height;

  /// The native request: assets, event trackers, context and options.
  /// Unset assets request Prebid's reference set; unset event trackers request
  /// impression trackers (image + JS); the context, subtype and placement
  /// default to social, general social and in-feed.
  final NativeParameters nativeParameters;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp`. iOS
  /// only: Prebid Android's mediation native ad unit has no setter for it.
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only. iOS only, as
  /// [impOrtbConfig].
  final String? globalOrtbConfig;

  /// Listener for native ad events.
  final PrebidAdMobNativeAdListener? listener;

  @override
  State<PrebidAdMobNativeAd> createState() => _PrebidAdMobNativeAdState();
}

class _PrebidAdMobNativeAdState extends State<PrebidAdMobNativeAd>
    with AdViewState<PrebidAdMobNativeAd> {
  @override
  String get viewType => 'prebid_mobile_sdk_admob/native';

  @override
  Map<String, Object?> configOf(PrebidAdMobNativeAd widget) => {
    'configId': widget.configId,
    'adMobAdUnitId': widget.adMobAdUnitId,
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
      case 'onAdImpression':
        l?.onAdImpression?.call();
      case 'onAdClicked':
        l?.onAdClicked?.call();
      case 'onAdOpened':
        l?.onAdOpened?.call();
      case 'onAdFailed':
        l?.onAdFailed?.call(adEventError(call.arguments));
    }
  }
}
