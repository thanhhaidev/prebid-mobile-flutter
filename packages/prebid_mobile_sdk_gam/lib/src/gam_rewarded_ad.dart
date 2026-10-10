import 'package:prebid_mobile_sdk/companion.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidFullscreenControls, PrebidRewardedAdListener, VideoParameters;

final _channel = CompanionAdChannel('prebid_mobile_sdk_gam/rewarded');

/// A fullscreen rewarded ad rendered by Google Ad Manager with Prebid demand.
///
/// On Android a [loadAd] made before the Prebid SDK finished initializing
/// reports `onAdFailed` ("The Prebid SDK is not initialized"): Prebid Android
/// drops such requests, so the ad would never load.
class PrebidGamRewardedAd extends CompanionFullscreenAd {
  /// Creates a [PrebidGamRewardedAd]. Call [loadAd] to request it.
  PrebidGamRewardedAd({
    required this.configId,
    required this.gamAdUnitId,
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

  /// The Google Ad Manager rewarded ad unit ID.
  final String gamAdUnitId;

  /// Custom key-values added to the Google Ad Manager request (Prebid 3.4).
  /// Prebid's own `hb_*` keys take precedence on conflict.
  final Map<String, String>? customTargeting;

  /// Close button, sound, and on iOS minimum-size and SKOverlay controls
  /// (skip controls apply on Android only; auto-close to interstitials only).
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

  /// OpenRTB video parameters for the rewarded video. iOS applies every
  /// field; Prebid Android's rewarded ad unit only exposes
  /// `setMaxVideoDuration`, so [VideoParameters.maxDuration] only caps the
  /// rendered video there (nothing is sent in the request).
  final VideoParameters? videoParameters;

  /// Listener for rewarded ad events.
  final PrebidRewardedAdListener? listener;

  @override
  Map<String, Object?> get loadArguments => {
    'configId': configId,
    'gamAdUnitId': gamAdUnitId,
    'customTargeting': ?customTargeting,
    'controls': ?controls?.toMap(),
    'impOrtbConfig': ?impOrtbConfig,
    'globalOrtbConfig': ?globalOrtbConfig,
    'pbAdSlot': ?pbAdSlot,
    'videoParameters': ?videoParameters?.toMap(),
  };

  @override
  void onEvent(String event, Map? args) =>
      dispatchRewardedEvent(listener, event, args);
}
