import 'package:prebid_mobile_sdk/companion.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidFullscreenControls, PrebidRewardedAdListener, VideoParameters;

import 'admob_testing.dart';

final _channel = CompanionAdChannel('prebid_mobile_sdk_admob/rewarded');

/// A fullscreen rewarded ad mediated by **Google AdMob** with Prebid demand,
/// via Prebid's AdMob rewarded adapter.
///
/// ```dart
/// final rewarded = PrebidAdMobRewardedAd(
///   configId: 'prebid-demo-video-rewarded-320-480',
///   adMobAdUnitId: 'ca-app-pub-3940256099942544/5224354917',
///   listener: PrebidRewardedAdListener(
///     onAdLoaded: () => rewarded.show(),
///     onUserEarnedReward: (r) => debugPrint('Earned ${r.count} ${r.type}'),
///     onAdClosed: () => rewarded.destroy(),
///   ),
/// );
/// await rewarded.loadAd();
/// ```
///
/// On Android a [loadAd] made before the Prebid SDK finished initializing
/// reports `onAdFailed` ("The Prebid SDK is not initialized"): Prebid Android
/// drops such requests, so AdMob's waterfall would never run.
class PrebidAdMobRewardedAd extends CompanionFullscreenAd {
  /// Creates a [PrebidAdMobRewardedAd].
  PrebidAdMobRewardedAd({
    required this.configId,
    required this.adMobAdUnitId,
    this.controls,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.pbAdSlot,
    this.videoParameters,
    this.listener,
  }) : super(_channel);

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AdMob rewarded ad unit ID.
  final String adMobAdUnitId;

  /// Close / skip button and sound controls. The minimum size and auto-close
  /// don't apply: Prebid's mediation rewarded ad unit has neither.
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

  /// OpenRTB video parameters for a video rewarded. iOS applies every field;
  /// Prebid Android's mediation ad unit only exposes `setMaxVideoDuration`, so
  /// [VideoParameters.maxDuration] only caps the rendered video there (nothing
  /// is sent in the request).
  final VideoParameters? videoParameters;

  /// Listener for rewarded ad events.
  final PrebidRewardedAdListener? listener;

  @override
  Map<String, Object?> get loadArguments => {
    'configId': configId,
    'adMobAdUnitId': adMobAdUnitId,
    'controls': ?controls?.toMap(),
    'impOrtbConfig': ?impOrtbConfig,
    'globalOrtbConfig': ?globalOrtbConfig,
    'pbAdSlot': ?pbAdSlot,
    'videoParameters': ?videoParameters?.toMap(),
    ...debugDropBidArgs(),
  };

  @override
  void onEvent(String event, Map? args) =>
      dispatchRewardedEvent(listener, event, args);
}
