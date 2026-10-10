import Foundation
import PrebidMobile

/// The JSON Prebid writes into the native request (`imp.native.request`) for
/// these assets and trackers: what the tests check, as Prebid iOS keeps the
/// asset and tracker fields internal.
func nativeRequestJSON(
  assets: [NativeAsset]? = nil,
  trackers: [NativeEventTracker]? = nil
) -> (assets: [NSDictionary], trackers: [NSDictionary]) {
  let request = NativeMarkupRequestObject()
  request.assets = assets
  request.eventtrackers = trackers
  let json = request.jsonDictionary
  return (
    (json["assets"] as? [[AnyHashable: Any]] ?? []).map { $0 as NSDictionary },
    (json["eventtrackers"] as? [[AnyHashable: Any]] ?? []).map { $0 as NSDictionary }
  )
}
