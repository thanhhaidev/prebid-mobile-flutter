import 'package:flutter/foundation.dart';

import 'ad_enums.dart';
import 'ad_listener.dart';
import 'banner_ad.dart';
import 'companion/companion_fullscreen_ad.dart';
import 'fullscreen_controls.dart';
import 'generated/prebid_api.g.dart';
import 'internal/fullscreen_ad.dart';
import 'internal/ortb.dart';
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
    this.gpid,
    this.adPosition,
    this.controls,
    this.listener,
  }) {
    _ad = FullscreenAdLifecycle((event, args) {
      dispatchInterstitialEvent(listener, event, args);
    });
  }

  /// The platform channel to the native SDK; tests replace it with a mock.
  @visibleForTesting
  static InterstitialAdHostApi api = InterstitialAdHostApi();

  late final FullscreenAdLifecycle _ad;

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

  /// Global Placement ID (`imp.ext.gpid`), added to [impOrtbConfig] (a
  /// `gpid` already there wins).
  final String? gpid;

  /// Ad position on screen (`imp.pos`; fullscreen for an interstitial).
  /// iOS only: Prebid Android's fullscreen ad units have no setter.
  final PrebidAdPosition? adPosition;

  /// Close / skip button, sound and minimum-size controls.
  final PrebidFullscreenControls? controls;

  /// Listener for interstitial ad events.
  final PrebidInterstitialAdListener? listener;

  /// Whether the ad has loaded and is ready to [show].
  bool get isLoaded => _ad.isLoaded;

  /// The winning bid of the last load, for analytics. Android only (Prebid
  /// iOS keeps it internal); null before a load and without a bid.
  PrebidWinningBid? get winningBid => _ad.winningBid;

  /// Load the interstitial ad. Also valid after [destroy].
  Future<void> loadAd() async {
    _ad.loading();
    await api.loadAd(
      _ad.adId,
      configId,
      adFormats?.map((f) => f.name).toList(),
      videoParameters?.toConfig(),
      impOrtbWithGpid(impOrtbConfig, gpid),
      globalOrtbConfig,
      controls?.toConfig(),
      pbAdSlot,
      adPosition?.value,
    );
  }

  /// Shows the loaded ad. An ad shows once, so [isLoaded] turns false; if it
  /// can't be shown the listener's `onAdFailed` fires.
  Future<void> show() async {
    _ad.showing();
    await api.show(_ad.adId);
  }

  /// Releases the native interstitial and stops event delivery to
  /// [listener] until the next [loadAd].
  Future<void> destroy() async {
    _ad.destroyed();
    await api.destroy(_ad.adId);
  }
}
