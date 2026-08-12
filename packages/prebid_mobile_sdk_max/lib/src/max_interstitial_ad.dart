import 'package:flutter/services.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show PrebidInterstitialAdListener;

const MethodChannel _channel = MethodChannel(
  'prebid_mobile_sdk_max/interstitial',
);

/// Routes native interstitial events (delivered over the shared method channel)
/// to the [PrebidMaxInterstitialAd] that owns each `adId`.
///
/// One handler is installed per channel, so a single router owns it and
/// dispatches by `adId` — mirroring the core plugin's event router.
class _MaxInterstitialRouter {
  _MaxInterstitialRouter._() {
    _channel.setMethodCallHandler(_onCall);
  }

  static final _MaxInterstitialRouter instance = _MaxInterstitialRouter._();

  final Map<int, PrebidMaxInterstitialAd> _ads = {};

  void register(int adId, PrebidMaxInterstitialAd ad) => _ads[adId] = ad;

  void unregister(int adId) => _ads.remove(adId);

  Future<dynamic> _onCall(MethodCall call) async {
    final args = call.arguments as Map?;
    final adId = (args?['adId'] as num?)?.toInt();
    if (adId == null) return;
    _ads[adId]?._handleEvent(call.method, args);
  }
}

/// A fullscreen interstitial ad mediated by **AppLovin MAX** with Prebid
/// demand, via Prebid's MAX interstitial adapter.
///
/// ```dart
/// final interstitial = PrebidMaxInterstitialAd(
///   configId: 'prebid-demo-display-interstitial-320-480',
///   maxAdUnitId: 'YOUR_MAX_INTERSTITIAL_AD_UNIT_ID',
///   listener: PrebidInterstitialAdListener(
///     onAdLoaded: () => interstitial.show(),
///     onAdClosed: () => interstitial.destroy(),
///   ),
/// );
/// await interstitial.loadAd();
/// ```
class PrebidMaxInterstitialAd {
  static int _nextId = 7000000;

  final int _adId;

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AppLovin MAX ad unit ID.
  final String maxAdUnitId;

  /// Whether the interstitial may fill with a video creative. Sets the Prebid
  /// mediation ad-unit format to video when true (banner otherwise).
  final bool isVideo;

  /// Listener for interstitial ad events.
  final PrebidInterstitialAdListener? listener;

  bool _loaded = false;

  /// Whether the interstitial has loaded and is ready to [show].
  bool get isLoaded => _loaded;

  /// Creates a [PrebidMaxInterstitialAd].
  PrebidMaxInterstitialAd({
    required this.configId,
    required this.maxAdUnitId,
    this.isVideo = false,
    this.listener,
  }) : _adId = _nextId++;

  /// Requests the ad. [PrebidInterstitialAdListener.onAdLoaded] fires when it is
  /// ready to [show].
  Future<void> loadAd() async {
    _MaxInterstitialRouter.instance.register(_adId, this);
    await _channel.invokeMethod('load', {
      'adId': _adId,
      'configId': configId,
      'maxAdUnitId': maxAdUnitId,
      'isVideo': isVideo,
    });
  }

  /// Presents the loaded interstitial fullscreen.
  Future<void> show() => _channel.invokeMethod('show', {'adId': _adId});

  /// Releases native resources held by this ad.
  Future<void> destroy() async {
    _MaxInterstitialRouter.instance.unregister(_adId);
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
