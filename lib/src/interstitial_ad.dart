import 'package:flutter/foundation.dart';

import 'ad_enums.dart';
import 'ad_event_router.dart';
import 'ad_listener.dart';
import 'generated/prebid_api.g.dart';
import 'video_parameters.dart';

/// A fullscreen interstitial ad using Prebid rendering.
///
/// Create an instance, call [loadAd], and then [show] when ready.
/// Call [destroy] when the ad is no longer needed.
class PrebidInterstitialAd {
  @visibleForTesting
  static InterstitialAdHostApi api = InterstitialAdHostApi();
  static int _nextId = 0;

  final int _adId;

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// The ad formats to request (banner, video, or both).
  final Set<AdFormat>? adFormats;

  /// Video playback parameters (protocols, playback methods, etc.).
  ///
  /// Only used when [adFormats] includes [AdFormat.video].
  final VideoParameters? videoParameters;

  /// Listener for interstitial ad events.
  final PrebidInterstitialAdListener? listener;

  /// Creates a [PrebidInterstitialAd].
  PrebidInterstitialAd({
    required this.configId,
    this.adFormats,
    this.videoParameters,
    this.listener,
  }) : _adId = _nextId++ {
    AdEventRouter.instance.register(_adId, _handleEvent);
  }

  void _handleEvent(AdEvent event) {
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
    }
  }

  /// Load the interstitial ad.
  Future<void> loadAd() async {
    final formats = adFormats?.map((f) => f.name).toList();
    VideoParametersConfig? videoConfig;
    if (videoParameters != null) {
      videoConfig = VideoParametersConfig(
        mimes: videoParameters!.mimes,
        protocols: videoParameters!.protocols?.map((p) => p.value).toList(),
        playbackMethods: videoParameters!.playbackMethods
            ?.map((m) => m.value)
            .toList(),
        placement: videoParameters!.placement?.value,
        maxDuration: videoParameters!.maxDuration,
        minDuration: videoParameters!.minDuration,
        api: videoParameters!.api?.map((a) => a.value).toList(),
      );
    }
    api.loadAd(_adId, configId, formats, videoConfig);
  }

  /// Show the interstitial ad.
  Future<void> show() async {
    api.show(_adId);
  }

  /// Destroy the interstitial ad and free resources.
  Future<void> destroy() async {
    AdEventRouter.instance.unregister(_adId);
    api.destroy(_adId);
  }
}

/// A fullscreen rewarded ad using Prebid rendering.
///
/// Create an instance, call [loadAd], and then [show] when ready.
/// Call [destroy] when the ad is no longer needed.
class PrebidRewardedAd {
  @visibleForTesting
  static RewardedAdHostApi api = RewardedAdHostApi();
  static int _nextId = 1000000; // offset to avoid conflicts with interstitials

  final int _adId;

  /// The Prebid Server stored impression configuration ID.
  final String configId;

  /// Listener for rewarded ad events.
  final PrebidRewardedAdListener? listener;

  /// Creates a [PrebidRewardedAd].
  PrebidRewardedAd({required this.configId, this.listener})
    : _adId = _nextId++ {
    AdEventRouter.instance.register(_adId, _handleEvent);
  }

  void _handleEvent(AdEvent event) {
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
        if (event.reward != null) {
          l.onUserEarnedReward?.call(
            PrebidReward(
              type: event.reward!.type ?? '',
              count: event.reward!.count ?? 0,
            ),
          );
        }
    }
  }

  /// Load the rewarded ad.
  Future<void> loadAd() async {
    api.loadAd(_adId, configId);
  }

  /// Show the rewarded ad.
  Future<void> show() async {
    api.show(_adId);
  }

  /// Destroy the rewarded ad and free resources.
  Future<void> destroy() async {
    AdEventRouter.instance.unregister(_adId);
    api.destroy(_adId);
  }
}
