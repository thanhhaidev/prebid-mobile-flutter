import 'dart:convert';

import 'package:meta/meta.dart';

import '../ad_listener.dart';
import 'companion_ad_channel.dart';

/// Base class of the companion packages' interstitial and rewarded ads.
///
/// It owns the ad id, the load / show / destroy calls on its
/// [CompanionAdChannel] and the [isLoaded] state; a subclass supplies the
/// `load` arguments and forwards events to its listener (usually with
/// [dispatchInterstitialEvent] or [dispatchRewardedEvent]).
abstract class CompanionFullscreenAd {
  /// Creates an ad that talks over [channel].
  CompanionFullscreenAd(this._channel) : adId = _nextId++;

  static int _nextId = 1;

  final CompanionAdChannel _channel;

  /// Identifies this ad in the native events.
  @protected
  final int adId;

  bool _loaded = false;

  /// Whether the ad has loaded and is ready to [show].
  bool get isLoaded => _loaded;

  /// The arguments of the native `load` call, besides `adId`.
  @protected
  Map<String, Object?> get loadArguments;

  /// Handles a native event after [isLoaded] has been updated.
  @protected
  void onEvent(String event, Map? args);

  /// Requests an ad; the result arrives on the listener.
  Future<void> loadAd() async {
    _loaded = false;
    _channel.register(adId, _handleEvent);
    await _channel.invoke('load', {'adId': adId, ...loadArguments});
  }

  /// Presents the loaded ad fullscreen. An ad shows once, so [isLoaded] turns
  /// false; if it can't be shown (not loaded yet, nothing to present from)
  /// the listener's `onAdFailed` fires.
  Future<void> show() {
    _loaded = false;
    return _channel.invoke('show', {'adId': adId});
  }

  /// Destroys the ad and releases its native resources. [loadAd] may be
  /// called again afterwards.
  Future<void> destroy() async {
    _loaded = false;
    _channel.unregister(adId);
    await _channel.invoke('destroy', {'adId': adId});
  }

  void _handleEvent(String event, Map? args) {
    switch (event) {
      case 'onAdLoaded':
        _loaded = true;
      case 'onAdFailed' || 'onAdClosed' || 'onAdExpired':
        _loaded = false;
    }
    onEvent(event, args);
  }
}

/// The `error` of an `onAdFailed` payload.
String companionError(Map? args) =>
    args?['error'] as String? ?? 'Unknown error';

/// Calls the [listener] callback for an interstitial [event]. Returns whether
/// the event is one of [PrebidInterstitialAdListener]'s.
bool dispatchInterstitialEvent(
  PrebidInterstitialAdListener? listener,
  String event,
  Map? args,
) {
  switch (event) {
    case 'onAdLoaded':
      listener?.onAdLoaded?.call();
    case 'onAdFailed':
      listener?.onAdFailed?.call(companionError(args));
    case 'onAdDisplayed':
      listener?.onAdDisplayed?.call();
    case 'onAdClosed':
      listener?.onAdClosed?.call();
    case 'onAdClicked':
      listener?.onAdClicked?.call();
    case 'onAdExpired':
      listener?.onAdExpired?.call();
    case 'onAdImpression':
      listener?.onAdImpression?.call();
    default:
      return false;
  }
  return true;
}

/// Calls the [listener] callback for a rewarded [event]. Returns whether the
/// event is one of [PrebidRewardedAdListener]'s.
bool dispatchRewardedEvent(
  PrebidRewardedAdListener? listener,
  String event,
  Map? args,
) {
  switch (event) {
    case 'onAdLoaded':
      listener?.onAdLoaded?.call();
    case 'onAdFailed':
      listener?.onAdFailed?.call(companionError(args));
    case 'onAdDisplayed':
      listener?.onAdDisplayed?.call();
    case 'onAdClosed':
      listener?.onAdClosed?.call();
    case 'onAdClicked':
      listener?.onAdClicked?.call();
    case 'onAdExpired':
      listener?.onAdExpired?.call();
    case 'onAdImpression':
      listener?.onAdImpression?.call();
    case 'onUserEarnedReward':
      listener?.onUserEarnedReward?.call(rewardFromPayload(args));
    default:
      return false;
  }
  return true;
}

/// Builds the [PrebidReward] of an `onUserEarnedReward` payload. Every
/// companion sends the same keys (`rewardType`, `rewardCount` and, when the
/// SDK provides one, `rewardExt` as a JSON string or map), so rewards look
/// the same whichever ad server renders them.
PrebidReward rewardFromPayload(Map? args) => PrebidReward(
  type: args?['rewardType'] as String? ?? 'reward',
  count: (args?['rewardCount'] as num?)?.toInt() ?? 1,
  ext: _decodeExt(args?['rewardExt']),
);

Map<String, dynamic>? _decodeExt(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is! String || raw.isEmpty) return null;
  // A malformed ext must not cost the app the reward callback itself.
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
}
