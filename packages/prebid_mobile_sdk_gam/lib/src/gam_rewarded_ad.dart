import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show
        PrebidFullscreenControls,
        PrebidReward,
        PrebidRewardedAdListener,
        VideoParameters;

const MethodChannel _channel = MethodChannel('prebid_mobile_sdk_gam/rewarded');

class _GamRewardedRouter {
  _GamRewardedRouter._() {
    _channel.setMethodCallHandler(_onCall);
  }

  static final _GamRewardedRouter instance = _GamRewardedRouter._();
  final Map<int, PrebidGamRewardedAd> _ads = {};

  void register(int adId, PrebidGamRewardedAd ad) => _ads[adId] = ad;
  void unregister(int adId) => _ads.remove(adId);

  Future<dynamic> _onCall(MethodCall call) async {
    final args = call.arguments as Map?;
    final adId = (args?['adId'] as num?)?.toInt();
    if (adId == null) return;
    _ads[adId]?._handleEvent(call.method, args);
  }
}

/// A fullscreen rewarded ad rendered by Google Ad Manager with Prebid demand.
class PrebidGamRewardedAd {
  static int _nextId = 6000000;

  final int _adId;

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The Google Ad Manager rewarded ad unit ID.
  final String gamAdUnitId;

  /// Custom key-values added to the Google Ad Manager request (Prebid 3.4).
  /// Prebid's own `hb_*` keys take precedence on conflict.
  final Map<String, String>? customTargeting;

  /// Close button, sound and (iOS) SKOverlay controls (skip controls apply on
  /// Android only).
  final PrebidFullscreenControls? controls;

  /// OpenRTB video parameters for the rewarded video. iOS applies every
  /// field; Prebid Android's rewarded ad unit only exposes
  /// `setMaxVideoDuration`, so [VideoParameters.maxDuration] only caps the
  /// rendered video there (nothing is sent in the request).
  final VideoParameters? videoParameters;

  /// Listener for rewarded ad events.
  final PrebidRewardedAdListener? listener;

  bool _loaded = false;

  /// Whether the rewarded ad has loaded and is ready to [show].
  bool get isLoaded => _loaded;

  PrebidGamRewardedAd({
    required this.configId,
    required this.gamAdUnitId,
    this.customTargeting,
    this.controls,
    this.videoParameters,
    this.listener,
  }) : _adId = _nextId++;

  Future<void> loadAd() async {
    _loaded = false;
    _GamRewardedRouter.instance.register(_adId, this);
    await _channel.invokeMethod('load', {
      'adId': _adId,
      'configId': configId,
      'gamAdUnitId': gamAdUnitId,
      'customTargeting': ?customTargeting,
      'controls': ?controls?.toMap(),
      'videoParameters': ?videoParameters?.toMap(),
    });
  }

  /// Presents the loaded rewarded ad fullscreen. An ad shows once, so [isLoaded]
  /// turns false; if it cannot be shown (not loaded yet, no foreground
  /// activity / view controller) the listener's `onAdFailed` fires.
  Future<void> show() {
    _loaded = false;
    return _channel.invokeMethod('show', {'adId': _adId});
  }

  Future<void> destroy() async {
    _loaded = false;
    _GamRewardedRouter.instance.unregister(_adId);
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
      case 'onUserEarnedReward':
        listener?.onUserEarnedReward?.call(_rewardFrom(args));
      case 'onAdExpired':
        _loaded = false;
        listener?.onAdExpired?.call();
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
  final decoded = jsonDecode(raw);
  return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
}
