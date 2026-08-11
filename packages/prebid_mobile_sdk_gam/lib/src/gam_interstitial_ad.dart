import 'package:flutter/services.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidInterstitialAdListener;

const MethodChannel _channel = MethodChannel(
  'prebid_mobile_sdk_gam/interstitial',
);

/// Routes native interstitial events (delivered over the shared method channel)
/// to the [PrebidGamInterstitialAd] that owns each `adId`.
///
/// One handler is installed per channel, so a single router owns it and
/// dispatches by `adId` — mirroring the core plugin's event router.
class _GamInterstitialRouter {
  _GamInterstitialRouter._() {
    _channel.setMethodCallHandler(_onCall);
  }

  static final _GamInterstitialRouter instance = _GamInterstitialRouter._();

  final Map<int, PrebidGamInterstitialAd> _ads = {};

  void register(int adId, PrebidGamInterstitialAd ad) => _ads[adId] = ad;

  void unregister(int adId) => _ads.remove(adId);

  Future<dynamic> _onCall(MethodCall call) async {
    final args = call.arguments as Map?;
    final adId = (args?['adId'] as num?)?.toInt();
    if (adId == null) return;
    _ads[adId]?._handleEvent(call.method, args);
  }
}

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
class PrebidGamInterstitialAd {
  static int _nextId = 5000000;

  final int _adId;

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The Google Ad Manager ad unit ID (e.g. `/1234567/your-interstitial`).
  final String gamAdUnitId;

  /// Listener for interstitial ad events.
  final PrebidInterstitialAdListener? listener;

  bool _loaded = false;

  /// Whether the interstitial has loaded and is ready to [show].
  bool get isLoaded => _loaded;

  /// Creates a [PrebidGamInterstitialAd].
  PrebidGamInterstitialAd({
    required this.configId,
    required this.gamAdUnitId,
    this.listener,
  }) : _adId = _nextId++;

  /// Requests the ad. [PrebidInterstitialAdListener.onAdLoaded] fires when it is
  /// ready to [show].
  Future<void> loadAd() async {
    _GamInterstitialRouter.instance.register(_adId, this);
    await _channel.invokeMethod('load', {
      'adId': _adId,
      'configId': configId,
      'gamAdUnitId': gamAdUnitId,
    });
  }

  /// Presents the loaded interstitial fullscreen.
  Future<void> show() => _channel.invokeMethod('show', {'adId': _adId});

  /// Releases native resources held by this ad.
  Future<void> destroy() async {
    _GamInterstitialRouter.instance.unregister(_adId);
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
    }
  }
}
