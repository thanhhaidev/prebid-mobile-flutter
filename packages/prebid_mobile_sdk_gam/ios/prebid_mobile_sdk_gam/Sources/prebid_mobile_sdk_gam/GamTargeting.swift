import Foundation

/// Reads the `customTargeting` creation/method argument (a String→String map
/// from Dart), or nil when absent or empty.
func gamCustomTargeting(_ raw: Any?) -> [String: String]? {
    guard let map = raw as? [String: String], !map.isEmpty else { return nil }
    return map
}
