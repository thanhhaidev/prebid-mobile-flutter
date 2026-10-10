import 'package:flutter/foundation.dart';

import 'ad_enums.dart';
import 'ad_listener.dart';
import 'companion/companion_fullscreen_ad.dart';
import 'fullscreen_controls.dart';
import 'generated/prebid_api.g.dart';
import 'internal/fullscreen_ad.dart';
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
    this.pbAdSlot,
    this.controls,
    this.listener,
  }) {
    _ad = FullscreenAdLifecycle((event, args) {
      dispatchRewardedEvent(listener, event, args);
    });
  }

  /// The platform channel to the native SDK; tests replace it with a mock.
  @visibleForTesting
  static RewardedAdHostApi api = RewardedAdHostApi();

  late final FullscreenAdLifecycle _ad;

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

  /// Prebid ad slot (`imp.ext.data.pbadslot`). Prebid iOS has no setter on
  /// this ad unit, so on iOS the plugin adds it to [impOrtbConfig] (a
  /// `pbadslot` already there wins).
  final String? pbAdSlot;

  /// Close button, sound and minimum-size controls. Skip controls apply on
  /// Android only; the minimum size on iOS only.
  final PrebidFullscreenControls? controls;

  /// Listener for rewarded ad events.
  final PrebidRewardedAdListener? listener;

  /// Whether the ad has loaded and is ready to [show].
  bool get isLoaded => _ad.isLoaded;

  /// Load the rewarded ad. Also valid after [destroy].
  Future<void> loadAd() async {
    _ad.loading();
    await api.loadAd(
      _ad.adId,
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
    _ad.showing();
    await api.show(_ad.adId);
  }

  /// Releases the native rewarded ad and stops event delivery to [listener]
  /// until the next [loadAd].
  Future<void> destroy() async {
    _ad.destroyed();
    await api.destroy(_ad.adId);
  }
}
