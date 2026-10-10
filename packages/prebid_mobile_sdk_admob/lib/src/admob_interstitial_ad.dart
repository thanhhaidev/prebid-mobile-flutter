import 'package:prebid_mobile_sdk/companion.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show
        PrebidAdFormat,
        PrebidFullscreenControls,
        PrebidInterstitialAdListener,
        VideoParameters;

import 'admob_testing.dart';

final _channel = CompanionAdChannel('prebid_mobile_sdk_admob/interstitial');

/// A fullscreen interstitial ad mediated by **Google AdMob** with Prebid
/// demand, via Prebid's AdMob interstitial adapter.
///
/// ```dart
/// final interstitial = PrebidAdMobInterstitialAd(
///   configId: 'prebid-demo-display-interstitial-320-480',
///   adMobAdUnitId: 'ca-app-pub-3940256099942544/1033173712',
///   listener: PrebidInterstitialAdListener(
///     onAdLoaded: () => interstitial.show(),
///     onAdClosed: () => interstitial.destroy(),
///   ),
/// );
/// await interstitial.loadAd();
/// ```
///
/// On Android a [loadAd] made before the Prebid SDK finished initializing
/// reports `onAdFailed` ("The Prebid SDK is not initialized"): Prebid Android
/// drops such requests, so AdMob's waterfall would never run.
class PrebidAdMobInterstitialAd extends CompanionFullscreenAd {
  /// Creates a [PrebidAdMobInterstitialAd].
  PrebidAdMobInterstitialAd({
    required this.configId,
    required this.adMobAdUnitId,
    this.isVideo = false,
    this.adFormats,
    this.controls,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.pbAdSlot,
    this.videoParameters,
    this.listener,
  }) : super(_channel);

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AdMob ad unit ID (e.g. `ca-app-pub-3940256099942544/1033173712`).
  final String adMobAdUnitId;

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

  /// Request-level OpenRTB JSON for this ad unit only (merged over
  /// `PrebidTargeting.setGlobalOrtbConfig`).
  final String? globalOrtbConfig;

  /// Prebid ad slot (`imp.ext.data.pbadslot`). Prebid iOS has no setter on
  /// this ad unit, so on iOS it is added to [impOrtbConfig] (a `pbadslot`
  /// already there wins).
  final String? pbAdSlot;

  /// OpenRTB video parameters for a video interstitial. iOS applies every field;
  /// Prebid Android's mediation ad unit only exposes `setMaxVideoDuration`, so
  /// [VideoParameters.maxDuration] only caps the rendered video there (nothing
  /// is sent in the request).
  final VideoParameters? videoParameters;

  /// Listener for interstitial ad events.
  final PrebidInterstitialAdListener? listener;

  @override
  Map<String, Object?> get loadArguments => {
    'configId': configId,
    'adMobAdUnitId': adMobAdUnitId,
    'controls': ?controls?.toMap(),
    'impOrtbConfig': ?impOrtbConfig,
    'globalOrtbConfig': ?globalOrtbConfig,
    'pbAdSlot': ?pbAdSlot,
    'videoParameters': ?videoParameters?.toMap(),
    'isVideo': isVideo,
    'adFormats': ?adFormats?.map((f) => f.name).toList(),
    ...debugDropBidArgs(),
  };

  @override
  void onEvent(String event, Map? args) =>
      dispatchInterstitialEvent(listener, event, args);
}
