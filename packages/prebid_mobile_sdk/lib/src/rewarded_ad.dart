import 'package:flutter/foundation.dart';

import 'ad_enums.dart';
import 'ad_listener.dart';
import 'fullscreen_controls.dart';
import 'generated/prebid_api.g.dart';
import 'internal/ad_event_router.dart';
import 'internal/pigeon_conversions.dart';
import 'video_parameters.dart';

/// A fullscreen rewarded ad using Prebid rendering.
///
/// Create an instance, call [loadAd], and then [show] when ready.
///
/// [destroy] releases the native ad unit; call it when the ad is no longer
/// needed (e.g. from `State.dispose`) or the native ad leaks. The object
/// stays usable: calling [loadAd] after [destroy] loads a fresh ad and its
/// events reach [listener] again.
class PrebidRewardedAd {
  /// Creates a [PrebidRewardedAd].
  PrebidRewardedAd({
    required this.configId,
    this.adFormats,
    this.videoParameters,
    this.impOrtbConfig,
    this.globalOrtbConfig,
    this.controls,
    this.listener,
  }) : _adId = _nextId++ {
    AdEventRouter.instance.register(_adId, _handleEvent);
  }

  /// The platform channel to the native SDK; tests replace it with a mock.
  @visibleForTesting
  static RewardedAdHostApi api = RewardedAdHostApi();
  static int _nextId = 1000000; // offset to avoid conflicts with interstitials

  final int _adId;

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The ad formats to request (banner, video, or both). iOS only: Prebid
  /// Android's rewarded ad unit has no format setter and requests both.
  final Set<PrebidAdFormat>? adFormats;

  /// OpenRTB video parameters. iOS applies every field; on Android only
  /// [VideoParameters.maxDuration] caps the rendered video.
  final VideoParameters? videoParameters;

  /// Impression-level OpenRTB JSON merged into this ad unit's `imp`.
  final String? impOrtbConfig;

  /// Request-level OpenRTB JSON for this ad unit only (merged over
  /// [PrebidTargeting.setGlobalOrtbConfig]).
  final String? globalOrtbConfig;

  /// Close button, sound and minimum-size controls. Skip controls apply on
  /// Android only; the minimum size on iOS only.
  final PrebidFullscreenControls? controls;

  /// Listener for rewarded ad events.
  final PrebidRewardedAdListener? listener;

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
      case 'onUserEarnedReward':
        // The platforms always attach a reward, defaulting to 'reward' x 1
        // (the companion packages' default too); mirror that if it's absent.
        final reward = event.reward;
        l.onUserEarnedReward?.call(
          PrebidReward(
            type: reward?.type ?? 'reward',
            count: reward?.count ?? 1,
            ext: reward?.ext?.map((k, v) => MapEntry(k ?? '', v)),
          ),
        );
      case 'onAdExpired':
        l.onAdExpired?.call();
    }
  }

  /// Load the rewarded ad. Also valid after [destroy].
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
    );
  }

  /// Shows the loaded ad. An ad shows once, so [isLoaded] turns false; if it
  /// can't be shown the listener's `onAdFailed` fires.
  Future<void> show() async {
    _loaded = false;
    await api.show(_adId);
  }

  /// Releases the native rewarded ad and stops event delivery to [listener]
  /// until the next [loadAd].
  Future<void> destroy() async {
    _loaded = false;
    AdEventRouter.instance.unregister(_adId);
    await api.destroy(_adId);
  }
}
