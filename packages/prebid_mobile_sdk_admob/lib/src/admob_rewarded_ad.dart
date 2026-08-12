import 'package:flutter/services.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidRewardedAdListener, PrebidReward;

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

  /// Listener for rewarded ad events.
  final PrebidRewardedAdListener? listener;

  bool _loaded = false;

  /// Whether the rewarded ad has loaded and is ready to [show].
  bool get isLoaded => _loaded;

  /// Creates a [PrebidAdMobRewardedAd].
  PrebidAdMobRewardedAd({
    required this.configId,
    required this.adMobAdUnitId,
    this.listener,
  }) : _adId = _nextId++;

  /// Requests the ad. [PrebidRewardedAdListener.onAdLoaded] fires when it is
  /// ready to [show].
  Future<void> loadAd() async {
    _AdMobRewardedRouter.instance.register(_adId, this);
    await _channel.invokeMethod('load', {
      'adId': _adId,
      'configId': configId,
      'adMobAdUnitId': adMobAdUnitId,
    });
  }

  /// Presents the loaded rewarded ad fullscreen.
  Future<void> show() => _channel.invokeMethod('show', {'adId': _adId});

  /// Releases native resources held by this ad.
  Future<void> destroy() async {
    _AdMobRewardedRouter.instance.unregister(_adId);
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
