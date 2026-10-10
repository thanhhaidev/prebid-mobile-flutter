import 'package:flutter/services.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show
        PrebidAdFormat,
        PrebidFullscreenControls,
        PrebidInterstitialAdListener,
        VideoParameters;

import 'max_listeners.dart';
import 'max_testing.dart';

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
  /// Creates a [PrebidMaxInterstitialAd].
  PrebidMaxInterstitialAd({
    required this.configId,
    required this.maxAdUnitId,
    this.isVideo = false,
    this.adFormats,
    this.controls,
    this.impOrtbConfig,
    this.videoParameters,
    this.listener,
  }) : _adId = _nextId++;
  static int _nextId = 7000000;

  final int _adId;

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The AppLovin MAX ad unit ID.
  final String maxAdUnitId;

  /// Whether the interstitial may fill with a video creative. Sets the Prebid
  /// mediation ad-unit format to video when true (banner otherwise).
  ///
  /// Ignored when [adFormats] is set.
  final bool isVideo;

  /// Formats to request — e.g. `{PrebidAdFormat.banner, PrebidAdFormat.video}` for a
  /// multiformat interstitial (the winning bid decides the creative).
  /// Overrides [isVideo] when set; an empty set falls back to [isVideo].
  final Set<PrebidAdFormat>? adFormats;

  /// Close / skip button, sound and (interstitial) minimum-size controls.
  final PrebidFullscreenControls? controls;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp`. Also
  /// how to set the GPID (`{"ext":{"gpid":"/1111/home"}}`) and the Prebid ad
  /// slot (`{"ext":{"data":{"pbadslot":"..."}}}`), which these units have no
  /// separate setters for on iOS.
  final String? impOrtbConfig;

  /// OpenRTB video parameters for a video interstitial. iOS applies every field;
  /// Prebid Android's mediation ad unit only exposes `setMaxVideoDuration`, so
  /// [VideoParameters.maxDuration] only caps the rendered video there (nothing
  /// is sent in the request).
  final VideoParameters? videoParameters;

  /// Listener for interstitial ad events. Pass a
  /// [PrebidMaxInterstitialAdListener] to also get MAX's revenue events.
  final PrebidInterstitialAdListener? listener;

  bool _loaded = false;

  /// Whether the interstitial has loaded and is ready to [show].
  bool get isLoaded => _loaded;

  /// Requests the ad. [PrebidInterstitialAdListener.onAdLoaded] fires when it is
  /// ready to [show].
  Future<void> loadAd() async {
    _loaded = false;
    _MaxInterstitialRouter.instance.register(_adId, this);
    await _channel.invokeMethod('load', {
      'adId': _adId,
      'configId': configId,
      'maxAdUnitId': maxAdUnitId,
      'controls': ?controls?.toMap(),
      'impOrtbConfig': ?impOrtbConfig,
      'videoParameters': ?videoParameters?.toMap(),
      'isVideo': isVideo,
      'adFormats': ?adFormats?.map((f) => f.name).toList(),
      ...debugDropBidArgs(),
    });
  }

  /// Presents the loaded interstitial fullscreen. An ad shows once, so [isLoaded]
  /// turns false; if it cannot be shown (not loaded yet, no foreground
  /// activity / view controller) the listener's `onAdFailed` fires.
  Future<void> show() {
    _loaded = false;
    return _channel.invokeMethod('show', {'adId': _adId});
  }

  /// Releases native resources held by this ad.
  Future<void> destroy() async {
    _loaded = false;
    _MaxInterstitialRouter.instance.unregister(_adId);
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
      case 'onAdRevenuePaid':
        final listener = this.listener;
        if (listener is PrebidMaxInterstitialAdListener) {
          listener.onAdRevenuePaid?.call(maxAdRevenueFrom(args));
        }
    }
  }
}
