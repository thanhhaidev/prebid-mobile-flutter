import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show
        PrebidFullscreenControls,
        PrebidReward,
        PrebidRewardedAdListener,
        VideoParameters;

import 'admob_testing.dart';

const MethodChannel _channel = MethodChannel(
  'prebid_mobile_sdk_admob/rewarded',
);

/// Routes native rewarded events (delivered over the shared method channel) to
/// the [PrebidAdMobRewardedAd] that owns each `adId`.
class _AdMobRewardedRouter {
  _AdMobRewardedRouter._() {
    _channel.setMethodCallHandler(_onCall);
  }

  static final _AdMobRewardedRouter instance = _AdMobRewardedRouter._();

  final Map<int, PrebidAdMobRewardedAd> _ads = {};

  void register(int adId, PrebidAdMobRewardedAd ad) => _ads[adId] = ad;

  void unregister(int adId) => _ads.remove(adId);

  Future<dynamic> _onCall(MethodCall call) async {
    final args = call.arguments as Map?;
    final adId = (args?['adId'] as num?)?.toInt();
    if (adId == null) return;
    _ads[adId]?._handleEvent(call.method, args);
  }
}

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
class PrebidAdMobRewardedAd {
  static int _nextId = 6500000;

  final int _adId;

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AdMob rewarded ad unit ID.
  final String adMobAdUnitId;

  /// Close / skip button, sound and (interstitial) minimum-size controls.
  final PrebidFullscreenControls? controls;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp`. Also
  /// how to set the GPID (`{"ext":{"gpid":"/1111/home"}}`) and the Prebid ad
  /// slot (`{"ext":{"data":{"pbadslot":"..."}}}`), which these units have no
  /// separate setters for on iOS.
  final String? impOrtbConfig;

  /// OpenRTB video parameters for a video rewarded. iOS applies every field;
  /// Prebid Android's mediation ad unit only exposes `setMaxVideoDuration`, so
  /// [VideoParameters.maxDuration] only caps the rendered video there (nothing
  /// is sent in the request).
  final VideoParameters? videoParameters;

  /// Listener for rewarded ad events.
  final PrebidRewardedAdListener? listener;

  bool _loaded = false;

  /// Whether the rewarded ad has loaded and is ready to [show].
  bool get isLoaded => _loaded;

  /// Creates a [PrebidAdMobRewardedAd].
  PrebidAdMobRewardedAd({
    required this.configId,
    required this.adMobAdUnitId,
    this.controls,
    this.impOrtbConfig,
    this.videoParameters,
    this.listener,
  }) : _adId = _nextId++;

  /// Requests the ad. [PrebidRewardedAdListener.onAdLoaded] fires when it is
  /// ready to [show].
  Future<void> loadAd() async {
    _loaded = false;
    _AdMobRewardedRouter.instance.register(_adId, this);
    await _channel.invokeMethod('load', {
      'adId': _adId,
      'configId': configId,
      'adMobAdUnitId': adMobAdUnitId,
      'controls': ?controls?.toMap(),
      'impOrtbConfig': ?impOrtbConfig,
      'videoParameters': ?videoParameters?.toMap(),
      ...debugDropBidArgs(),
    });
  }

  /// Presents the loaded rewarded ad fullscreen. An ad shows once, so [isLoaded]
  /// turns false; if it cannot be shown (not loaded yet, no foreground
  /// activity / view controller) the listener's `onAdFailed` fires.
  Future<void> show() {
    _loaded = false;
    return _channel.invokeMethod('show', {'adId': _adId});
  }

  /// Releases native resources held by this ad.
  Future<void> destroy() async {
    _loaded = false;
    _AdMobRewardedRouter.instance.unregister(_adId);
    await _channel.invokeMethod('destroy', {'adId': _adId});
  }

  void _handleEvent(String event, Map? args) {
    switch (event) {
      case 'onAdLoaded':
        _loaded = true;
        listener?.onAdLoaded?.call();
      case 'onAdFailed':
        _loaded = false;
        listener?.onAdFailed?.call(args?['error'] as String? ?? '');
      case 'onAdDisplayed':
        listener?.onAdDisplayed?.call();
      case 'onAdClosed':
        _loaded = false;
        listener?.onAdClosed?.call();
      case 'onAdClicked':
        listener?.onAdClicked?.call();
      case 'onAdImpression':
        listener?.onAdImpression?.call();
      case 'onUserEarnedReward':
        listener?.onUserEarnedReward?.call(_rewardFrom(args));
    }
  }
}

/// Builds the [PrebidReward] from an `onUserEarnedReward` payload. Every
/// companion package sends the same keys (`rewardType`, `rewardCount` and,
/// when the SDK provides one, `rewardExt` as a JSON string), so rewards look
/// identical whichever ad server renders them.
PrebidReward _rewardFrom(Map? args) => PrebidReward(
  type: args?['rewardType'] as String? ?? 'reward',
  count: (args?['rewardCount'] as num?)?.toInt() ?? 1,
  ext: _decodeExt(args?['rewardExt']),
);

Map<String, dynamic>? _decodeExt(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is! String || raw.isEmpty) return null;
  // A malformed ext must not cost the app the reward callback itself.
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
}
