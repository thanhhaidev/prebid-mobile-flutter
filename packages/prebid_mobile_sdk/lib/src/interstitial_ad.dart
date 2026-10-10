import 'package:flutter/foundation.dart';

import 'ad_enums.dart';
import 'ad_listener.dart';
import 'fullscreen_controls.dart';
import 'generated/prebid_api.g.dart';
import 'internal/ad_event_router.dart';
import 'internal/pigeon_conversions.dart';
import 'video_parameters.dart';

/// A fullscreen interstitial ad using Prebid rendering.
///
/// Create an instance, call [loadAd], and then [show] when ready.
///
/// [destroy] releases the native ad unit; call it when the ad is no longer
/// needed (e.g. from `State.dispose`) or the native ad leaks. The object
/// stays usable: calling [loadAd] after [destroy] loads a fresh ad and its
/// events reach [listener] again.
class PrebidInterstitialAd {
  /// Creates a [PrebidInterstitialAd].
  PrebidInterstitialAd({
    required this.configId,
    this.adFormats,
    this.videoParameters,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.pbAdSlot,
    this.controls,
    this.listener,
  }) : _adId = _nextId++ {
    AdEventRouter.instance.register(_adId, _handleEvent);
  }

  /// The platform channel to the native SDK; tests replace it with a mock.
  @visibleForTesting
  static InterstitialAdHostApi api = InterstitialAdHostApi();
  static int _nextId = 0;

  final int _adId;

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The ad formats to request (banner, video, or both).
  final Set<PrebidAdFormat>? adFormats;

  /// Video playback parameters (protocols, playback methods, etc.).
  ///
  /// Only used when [adFormats] includes [PrebidAdFormat.video]. On Android the
  /// rendering API has no video-parameters setter: the request carries the
  /// SDK's defaults and `maxDuration` only caps the rendered video's length.
  final VideoParameters? videoParameters;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp` (e.g.
  /// `{"ext":{"gpid":"/1111/interstitial"}}`).
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only (merged over
  /// [PrebidTargeting.setGlobalOrtbConfig]).
  final String? globalOrtbConfig;

  /// Prebid ad slot (`imp.ext.data.pbadslot`). Prebid iOS has no setter on
  /// this ad unit, so on iOS the plugin adds it to [impOrtbConfig] (a
  /// `pbadslot` already there wins).
  final String? pbAdSlot;

  /// Close / skip button, sound and minimum-size controls.
  final PrebidFullscreenControls? controls;

  /// Listener for interstitial ad events.
  final PrebidInterstitialAdListener? listener;

  bool _loaded = false;

  /// Whether the ad has loaded and is ready to [show].
  bool get isLoaded => _loaded;

  void _handleEvent(AdEvent event) {
    _loaded = switch (event.eventName) {
      'onAdLoaded' => true,
      'onAdFailed' || 'onAdClosed' || 'onAdExpired' => false,
      _ => _loaded,
    };
    final l = listener;
    if (l == null) return;
    switch (event.eventName) {
      case 'onAdLoaded':
        l.onAdLoaded?.call();
      case 'onAdFailed':
        l.onAdFailed?.call(event.error ?? 'Unknown error');
      case 'onAdDisplayed':
        l.onAdDisplayed?.call();
      case 'onAdClosed':
        l.onAdClosed?.call();
      case 'onAdClicked':
        l.onAdClicked?.call();
      case 'onAdExpired':
        l.onAdExpired?.call();
    }
  }

  /// Load the interstitial ad. Also valid after [destroy].
  Future<void> loadAd() async {
    _loaded = false;
    // Re-register: [destroy] unregisters, and the object may be reused.
    AdEventRouter.instance.register(_adId, _handleEvent);
    await api.loadAd(
      _adId,
      configId,
      adFormats?.map((f) => f.name).toList(),
      videoParameters?.toConfig(),
      impOrtbConfig,
      globalOrtbConfig,
      controls?.toConfig(),
      pbAdSlot,
    );
  }

  /// Shows the loaded ad. An ad shows once, so [isLoaded] turns false; if it
  /// can't be shown the listener's `onAdFailed` fires.
  Future<void> show() async {
    _loaded = false;
    await api.show(_adId);
  }

  /// Releases the native interstitial and stops event delivery to
  /// [listener] until the next [loadAd].
  Future<void> destroy() async {
    _loaded = false;
    AdEventRouter.instance.unregister(_adId);
    await api.destroy(_adId);
  }
}
