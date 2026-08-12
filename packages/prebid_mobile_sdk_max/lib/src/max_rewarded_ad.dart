import 'package:flutter/services.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidRewardedAdListener, PrebidReward;

const MethodChannel _channel = MethodChannel('prebid_mobile_sdk_max/rewarded');

/// Routes native rewarded events (delivered over the shared method channel) to
/// the [PrebidMaxRewardedAd] that owns each `adId`.
class _MaxRewardedRouter {
  _MaxRewardedRouter._() {
    _channel.setMethodCallHandler(_onCall);
  }

  static final _MaxRewardedRouter instance = _MaxRewardedRouter._();

  final Map<int, PrebidMaxRewardedAd> _ads = {};

  void register(int adId, PrebidMaxRewardedAd ad) => _ads[adId] = ad;

  void unregister(int adId) => _ads.remove(adId);

  Future<dynamic> _onCall(MethodCall call) async {
    final args = call.arguments as Map?;
    final adId = (args?['adId'] as num?)?.toInt();
    if (adId == null) return;
    _ads[adId]?._handleEvent(call.method, args);
  }
}

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
class PrebidMaxRewardedAd {
  static int _nextId = 7500000;

  final int _adId;

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AppLovin MAX rewarded ad unit ID.
  final String maxAdUnitId;

  /// Listener for rewarded ad events.
  final PrebidRewardedAdListener? listener;

  bool _loaded = false;

  /// Whether the rewarded ad has loaded and is ready to [show].
  bool get isLoaded => _loaded;

  /// Creates a [PrebidMaxRewardedAd].
  PrebidMaxRewardedAd({
    required this.configId,
    required this.maxAdUnitId,
    this.listener,
  }) : _adId = _nextId++;

  /// Requests the ad. [PrebidRewardedAdListener.onAdLoaded] fires when it is
  /// ready to [show].
  Future<void> loadAd() async {
    _MaxRewardedRouter.instance.register(_adId, this);
    await _channel.invokeMethod('load', {
      'adId': _adId,
      'configId': configId,
      'maxAdUnitId': maxAdUnitId,
    });
  }

  /// Presents the loaded rewarded ad fullscreen.
  Future<void> show() => _channel.invokeMethod('show', {'adId': _adId});

  /// Releases native resources held by this ad.
  Future<void> destroy() async {
    _MaxRewardedRouter.instance.unregister(_adId);
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
            type: args?['type'] as String?,
            count: (args?['count'] as num?)?.toInt(),
          ),
        );
    }
  }
}
