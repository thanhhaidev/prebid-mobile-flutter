import '../generated/prebid_api.g.dart';
import 'session.dart';

/// Routes [MultiformatFlutterApi] events (auto-refreshed results) to the
/// `PrebidMultiformatAd` with the event's ad id.
///
/// Internal: not exported from the public library.
class MultiformatEventRouter implements MultiformatFlutterApi {
  MultiformatEventRouter._() {
    // Created with this isolate's first multiformat or Original API unit.
    releasePreviousIsolateAds();
    MultiformatFlutterApi.setUp(this);
  }

  /// The process-wide router, bound to the channel on first use.
  static final MultiformatEventRouter instance = MultiformatEventRouter._();

  final Map<int, void Function(MultiformatBidResult result)> _handlers = {};

  /// Routes results for [adId] to [handler].
  void register(int adId, void Function(MultiformatBidResult) handler) {
    _handlers[adId] = handler;
  }

  /// Stops routing results for [adId].
  void unregister(int adId) {
    _handlers.remove(adId);
  }

  /// Delivers an auto-refreshed auction result to the ad it belongs to.
  @override
  Future<void> onDemandRefreshed(int adId, MultiformatBidResult result) async {
    _handlers[adId]?.call(result);
  }
}
