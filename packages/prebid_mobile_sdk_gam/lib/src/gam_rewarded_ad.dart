import 'package:flutter/services.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidReward, PrebidRewardedAdListener;

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

  /// Listener for rewarded ad events.
  final PrebidRewardedAdListener? listener;

  bool _loaded = false;

  /// Whether the rewarded ad has loaded and is ready to [show].
  bool get isLoaded => _loaded;

  PrebidGamRewardedAd({
    required this.configId,
    required this.gamAdUnitId,
    this.listener,
  }) : _adId = _nextId++;

  Future<void> loadAd() async {
    _GamRewardedRouter.instance.register(_adId, this);
    await _channel.invokeMethod('load', {
      'adId': _adId,
      'configId': configId,
      'gamAdUnitId': gamAdUnitId,
    });
  }

  Future<void> show() => _channel.invokeMethod('show', {'adId': _adId});

  Future<void> destroy() async {
    _GamRewardedRouter.instance.unregister(_adId);
    await _channel.invokeMethod('destroy', {'adId': _adId});
  }

  void _handleEvent(String event, Map? args) {
    switch (event) {
      case 'onAdLoaded':
        _loaded = true;
        listener?.onAdLoaded?.call();
      case 'onAdFailed':
        listener?.onAdFailed?.call(args?['error'] as String? ?? '');
      case 'onAdDisplayed':
        listener?.onAdDisplayed?.call();
      case 'onAdClosed':
        listener?.onAdClosed?.call();
      case 'onAdClicked':
        listener?.onAdClicked?.call();
      case 'onUserEarnedReward':
        listener?.onUserEarnedReward?.call(
          PrebidReward(
            type: args?['rewardType'] as String? ?? 'reward',
            count: (args?['rewardCount'] as num?)?.toInt() ?? 1,
          ),
        );
    }
  }
}
