import 'package:prebid_mobile_sdk/companion.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidFullscreenControls, PrebidRewardedAdListener, VideoParameters;

import 'max_listeners.dart';
import 'max_testing.dart';

final CompanionAdChannel _channel = CompanionAdChannel(
  'prebid_mobile_sdk_max/rewarded',
);

/// A fullscreen rewarded ad mediated by **AppLovin MAX** with Prebid demand,
/// via Prebid's MAX rewarded adapter.
///
/// ```dart
/// final rewarded = PrebidMaxRewardedAd(
///   configId: 'prebid-demo-video-rewarded-320-480-without-end-card',
///   maxAdUnitId: 'YOUR_MAX_REWARDED_AD_UNIT_ID',
///   listener: PrebidRewardedAdListener(
///     onAdLoaded: () => rewarded.show(),
///     onUserEarnedReward: (r) => debugPrint('Earned ${r.count} ${r.type}'),
///     onAdClosed: () => rewarded.destroy(),
///   ),
/// );
/// await rewarded.loadAd();
/// ```
class PrebidMaxRewardedAd extends CompanionFullscreenAd {
  /// Creates a [PrebidMaxRewardedAd].
  PrebidMaxRewardedAd({
    required this.configId,
    required this.maxAdUnitId,
    this.controls,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.pbAdSlot,
    this.gpid,
    this.videoParameters,
    this.listener,
  }) : super(_channel);

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AppLovin MAX rewarded ad unit ID.
  final String maxAdUnitId;

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

  /// Global Placement ID (`imp.ext.gpid`), e.g. `/1111/home`. Sent in
  /// [impOrtbConfig]; a `gpid` already there wins.
  final String? gpid;

  /// OpenRTB video parameters for a video rewarded. iOS applies every field;
  /// Prebid Android's mediation ad unit only exposes `setMaxVideoDuration`, so
  /// [VideoParameters.maxDuration] only caps the rendered video there (nothing
  /// is sent in the request).
  final VideoParameters? videoParameters;

  /// Listener for rewarded ad events. Pass a [PrebidMaxRewardedAdListener]
  /// to also get MAX's revenue events.
  final PrebidRewardedAdListener? listener;

  @override
  Map<String, Object?> get loadArguments => {
    'configId': configId,
    'maxAdUnitId': maxAdUnitId,
    'controls': ?controls?.toMap(),
    'impOrtbConfig': ?impOrtbWithGpid(impOrtbConfig, gpid),
    'globalOrtbConfig': ?globalOrtbConfig,
    'pbAdSlot': ?pbAdSlot,
    'videoParameters': ?videoParameters?.toMap(),
    ...debugDropBidArgs(),
  };

  @override
  void onEvent(String event, Map? args) {
    if (dispatchRewardedEvent(listener, event, args)) return;
    final maxListener = listener;
    if (maxListener is! PrebidMaxRewardedAdListener) return;
    switch (event) {
      case 'onAdDisplayFailed':
        maxListener.onAdDisplayFailed?.call(adEventError(args));
      case 'onAdRevenuePaid':
        maxListener.onAdRevenuePaid?.call(maxAdRevenueFrom(args));
    }
  }
}
