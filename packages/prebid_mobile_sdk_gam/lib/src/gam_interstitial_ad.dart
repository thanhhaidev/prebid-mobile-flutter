import 'package:prebid_mobile_sdk/companion.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show
        PrebidAdFormat,
        PrebidFullscreenControls,
        PrebidInterstitialAdListener,
        VideoParameters;

final _channel = CompanionAdChannel('prebid_mobile_sdk_gam/interstitial');

/// A fullscreen interstitial ad rendered by **Google Ad Manager** with Prebid
/// demand, via Prebid's GAM interstitial event handler.
///
/// ```dart
/// final interstitial = PrebidGamInterstitialAd(
///   configId: 'prebid-demo-display-interstitial-320-480',
///   gamAdUnitId: '/21808260008/prebid_oxb_html_interstitial',
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
/// drops such requests, so the ad would never load.
class PrebidGamInterstitialAd extends CompanionFullscreenAd {
  /// Creates a [PrebidGamInterstitialAd].
  PrebidGamInterstitialAd({
    required this.configId,
    required this.gamAdUnitId,
    this.isVideo = false,
    this.adFormats,
    this.customTargeting,
    this.controls,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.pbAdSlot,
    this.videoParameters,
    this.listener,
  }) : super(_channel);

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The Google Ad Manager ad unit ID (e.g. `/1234567/your-interstitial`).
  final String gamAdUnitId;

  /// Whether the interstitial may fill with a video creative: requests the
  /// video format when true (display otherwise).
  ///
  /// Ignored when [adFormats] is set.
  final bool isVideo;

  /// Formats to request — e.g. `{PrebidAdFormat.banner, PrebidAdFormat.video}`
  /// for a multiformat interstitial (the winning bid decides the creative).
  /// Overrides [isVideo] when set; an empty set falls back to [isVideo].
  final Set<PrebidAdFormat>? adFormats;

  /// Custom key-values added to the Google Ad Manager request (Prebid 3.4).
  /// Prebid's own `hb_*` keys take precedence on conflict.
  final Map<String, String>? customTargeting;

  /// Listener for interstitial ad events.
  final PrebidInterstitialAdListener? listener;

  /// Close / skip button, sound, minimum-size and (iOS) SKOverlay controls.
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

  /// OpenRTB video parameters for a video interstitial. iOS applies every
  /// field; Prebid Android's interstitial ad unit only exposes
  /// `setMaxVideoDuration`, so [VideoParameters.maxDuration] only caps the
  /// rendered video there (nothing is sent in the request).
  final VideoParameters? videoParameters;

  @override
  Map<String, Object?> get loadArguments => {
    'configId': configId,
    'gamAdUnitId': gamAdUnitId,
    'isVideo': isVideo,
    'adFormats': ?adFormats?.map((f) => f.name).toList(),
    'customTargeting': ?customTargeting,
    'controls': ?controls?.toMap(),
    'impOrtbConfig': ?impOrtbConfig,
    'globalOrtbConfig': ?globalOrtbConfig,
    'pbAdSlot': ?pbAdSlot,
    'videoParameters': ?videoParameters?.toMap(),
  };

  @override
  void onEvent(String event, Map? args) =>
      dispatchInterstitialEvent(listener, event, args);
}
