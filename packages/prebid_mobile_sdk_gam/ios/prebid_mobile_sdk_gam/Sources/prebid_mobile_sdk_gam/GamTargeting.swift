import Foundation
import GoogleMobileAds

/// Reads the `customTargeting` creation/method argument (a String→String map
/// from Dart), or nil when absent or empty.
func gamCustomTargeting(_ raw: Any?) -> [String: String]? {
    guard let map = raw as? [String: String], !map.isEmpty else { return nil }
    return map
}

/// The event handler's `adManagerRequestConfiguration` for the
/// `customTargeting` argument (Prebid 3.4): the app's keys on the GAM
/// request, under Prebid's hb_* keys, which still take precedence. Nil
/// without targeting.
func gamRequestConfiguration(_ raw: Any?) -> ((AdManagerRequest) -> Void)? {
    guard let targeting = gamCustomTargeting(raw) else { return nil }
    return { request in
        var merged = request.customTargeting ?? [:]
        merged.merge(targeting) { _, app in app }
        request.customTargeting = merged
    }
}
