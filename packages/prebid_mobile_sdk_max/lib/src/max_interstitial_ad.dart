import 'package:prebid_mobile_sdk/companion.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show
        PrebidAdFormat,
        PrebidFullscreenControls,
        PrebidInterstitialAdListener,
        VideoParameters;

import 'max_listeners.dart';
import 'max_testing.dart';

final CompanionAdChannel _channel = CompanionAdChannel(
  'prebid_mobile_sdk_max/interstitial',
);

/// A fullscreen interstitial ad mediated by **AppLovin MAX** with Prebid
/// demand, via Prebid's MAX interstitial adapter.
///
/// ```dart
/// final interstitial = PrebidMaxInterstitialAd(
///   configId: 'prebid-demo-display-interstitial-320-480',
///   maxAdUnitId: 'YOUR_MAX_INTERSTITIAL_AD_UNIT_ID',
///   listener: PrebidInterstitialAdListener(
///     onAdLoaded: () => interstitial.show(),
///     onAdClosed: () => interstitial.destroy(),
///   ),
/// );
/// await interstitial.loadAd();
/// ```
class PrebidMaxInterstitialAd extends CompanionFullscreenAd {
  /// Creates a [PrebidMaxInterstitialAd].
  PrebidMaxInterstitialAd({
    required this.configId,
    required this.maxAdUnitId,
    this.isVideo = false,
    this.adFormats,
    this.controls,
    this.impOrtbConfig,
    this.videoParameters,
    this.listener,
  }) : super(_channel);

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AppLovin MAX ad unit ID.
  final String maxAdUnitId;

  /// Whether the interstitial may fill with a video creative. Sets the Prebid
  /// mediation ad-unit format to video when true (banner otherwise).
  ///
  /// Ignored when [adFormats] is set.
  final bool isVideo;

  /// Formats to request — e.g. `{PrebidAdFormat.banner, PrebidAdFormat.video}` for a
  /// multiformat interstitial (the winning bid decides the creative).
  /// Overrides [isVideo] when set; an empty set falls back to [isVideo].
  final Set<PrebidAdFormat>? adFormats;

  /// Close / skip button, sound and (interstitial) minimum-size controls.
  final PrebidFullscreenControls? controls;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp`. Also
  /// how to set the GPID (`{"ext":{"gpid":"/1111/home"}}`) and the Prebid ad
  /// slot (`{"ext":{"data":{"pbadslot":"..."}}}`), which these units have no
  /// separate setters for on iOS.
  final String? impOrtbConfig;

  /// OpenRTB video parameters for a video interstitial. iOS applies every field;
  /// Prebid Android's mediation ad unit only exposes `setMaxVideoDuration`, so
  /// [VideoParameters.maxDuration] only caps the rendered video there (nothing
  /// is sent in the request).
  final VideoParameters? videoParameters;

  /// Listener for interstitial ad events. Pass a
  /// [PrebidMaxInterstitialAdListener] to also get MAX's revenue events.
  final PrebidInterstitialAdListener? listener;

  @override
  Map<String, Object?> get loadArguments => {
    'configId': configId,
    'maxAdUnitId': maxAdUnitId,
    'controls': ?controls?.toMap(),
    'impOrtbConfig': ?impOrtbConfig,
    'videoParameters': ?videoParameters?.toMap(),
    'isVideo': isVideo,
    'adFormats': ?adFormats?.map((f) => f.name).toList(),
    ...debugDropBidArgs(),
  };

  /// Requests the ad. [PrebidInterstitialAdListener.onAdLoaded] fires when it is
  /// ready to [show]; [PrebidInterstitialAdListener.onAdFailed] fires instead
  /// when it can't load (on Android also when the Prebid SDK isn't
  /// initialized yet).
  @override
  Future<void> loadAd() => super.loadAd();

  /// Presents the loaded interstitial fullscreen. An ad shows once, so [isLoaded]
  /// turns false; if it cannot be shown (not loaded yet, no foreground
  /// activity / view controller) the listener's `onAdFailed` fires.
  @override
  Future<void> show() => super.show();

  /// Releases native resources held by this ad. [loadAd] may be called again
  /// afterwards.
  @override
  Future<void> destroy() => super.destroy();

  @override
  void onEvent(String event, Map? args) {
    if (dispatchInterstitialEvent(listener, event, args)) return;
    final maxListener = listener;
    if (event == 'onAdRevenuePaid' &&
        maxListener is PrebidMaxInterstitialAdListener) {
      maxListener.onAdRevenuePaid?.call(maxAdRevenueFrom(args));
    }
  }
}
