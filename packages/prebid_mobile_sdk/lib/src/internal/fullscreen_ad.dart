import '../companion/companion_ad_channel.dart';
import '../generated/prebid_api.g.dart';
import 'ad_event_router.dart';
import 'ad_ids.dart';

/// What the core interstitial and rewarded ads share: the ad id, the event
/// routing (stopped by [destroyed], restarted by [loading]) and [isLoaded].
///
/// Events reach [dispatch] as the companion packages' event names and
/// payloads, so the same `dispatchInterstitialEvent` /
/// `dispatchRewardedEvent` serve both.
class FullscreenAdLifecycle {
  /// Starts routing the events of a new ad id to [dispatch].
  FullscreenAdLifecycle(this.dispatch) : adId = nextAdId() {
    _register();
  }

  /// Identifies the ad on the native side.
  final int adId;

  /// Forwards one event to the ad's listener.
  final CompanionAdEventHandler dispatch;

  /// Whether the ad has loaded and can be shown.
  bool get isLoaded => _loaded;
  bool _loaded = false;

  /// Before a load: also valid after [destroyed], which stopped the events.
  void loading() {
    _loaded = false;
    _register();
  }

  /// Before a show: an ad shows once.
  void showing() => _loaded = false;

  /// The ad was destroyed: no more events until the next [loading].
  void destroyed() {
    _loaded = false;
    AdEventRouter.instance.unregister(adId);
  }

  void _register() => AdEventRouter.instance.register(adId, _onEvent);

  void _onEvent(AdEvent event) {
    _loaded = switch (event.eventName) {
      'onAdLoaded' => true,
      'onAdFailed' || 'onAdClosed' || 'onAdExpired' => false,
      _ => _loaded,
    };
    final reward = event.reward;
    dispatch(event.eventName, {
      'error': ?event.error,
      if (reward != null) ...{
        'rewardType': reward.type,
        'rewardCount': reward.count,
        'rewardExt': reward.ext?.map((k, v) => MapEntry(k ?? '', v)),
      },
    });
  }
}
