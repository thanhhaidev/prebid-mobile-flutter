import 'generated/prebid_api.g.dart';

/// Single owner of the Pigeon [AdFlutterApi] event channel.
///
/// [AdFlutterApi.setUp] binds exactly one handler per channel (it calls
/// `setMessageHandler`, which replaces any previous handler), so the last
/// caller wins. Interstitial, rewarded, and native ads all receive their
/// events over this one channel and therefore must share a single handler —
/// otherwise whichever ad type registered last silently swallows every other
/// type's events (including `onAdLoaded`).
///
/// This router owns that single handler and dispatches each [AdEvent] to the
/// ad registered under its [AdEvent.adId]. Ad-id ranges are allocated so they
/// never overlap across ad types.
class AdEventRouter implements AdFlutterApi {
  AdEventRouter._() {
    AdFlutterApi.setUp(this);
  }

  /// The process-wide router. Created — and bound to the channel — on first use.
  static final AdEventRouter instance = AdEventRouter._();

  final Map<int, void Function(AdEvent event)> _handlers = {};

  /// Routes events for [adId] to [handler] until [unregister] is called.
  void register(int adId, void Function(AdEvent event) handler) {
    _handlers[adId] = handler;
  }

  /// Stops routing events for [adId].
  void unregister(int adId) {
    _handlers.remove(adId);
  }

  @override
  void onAdEvent(AdEvent event) {
    _handlers[event.adId]?.call(event);
  }
}
