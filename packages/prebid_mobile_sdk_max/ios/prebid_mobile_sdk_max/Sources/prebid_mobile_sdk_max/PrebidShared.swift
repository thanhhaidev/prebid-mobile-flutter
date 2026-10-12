import AppLovinSDK
import CoreGraphics
import Flutter
import Foundation
import PrebidMobile
import UIKit

// This package's own helpers; what every companion shares is in
// PrebidPlugin and PrebidRequests.

extension PrebidErrorFormatter {
    /// A MAX error's message (`MAError` is no `Error`), with the same
    /// fallback.
    static func describe(_ error: MAError?) -> String {
        guard let message = error?.message, !message.isEmpty else { return "Unknown error" }
        return message
    }
}

/// The `onAdRevenuePaid` payload (`PrebidMaxAdRevenue` on the Dart side).
func revenuePayload(_ ad: MAAd) -> [String: Any] {
    var payload: [String: Any] = [
        "revenue": ad.revenue,
        "revenuePrecision": ad.revenuePrecision,
        "networkName": ad.networkName,
    ]
    if let placement = ad.placement { payload["placement"] = placement }
    return payload
}
