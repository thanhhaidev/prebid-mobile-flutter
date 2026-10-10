import Foundation
import CoreGraphics
import Flutter
import UIKit
import PrebidMobile
import AppLovinSDK

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

extension FullscreenControls {
    // `supportSKOverlay` has no mediation equivalent: Prebid's mediation ad
    // units don't expose it (AdMob / AppLovin render the ad), so it is ignored.
    func apply(to adUnit: MediationBaseInterstitialAdUnit) {
        if let v = closeButtonArea { adUnit.closeButtonArea = v }
        if let v = closeButtonPosition { adUnit.closeButtonPosition = v }
        if let v = isMuted { adUnit.isMuted = v }
        if let v = isSoundButtonVisible { adUnit.isSoundButtonVisible = v }
        // Skip / auto-close exist on interstitials only (none on rewarded).
        if let interstitial = adUnit as? MediationInterstitialAdUnit {
            if let v = skipButtonArea { interstitial.skipButtonArea = v }
            if let v = skipButtonPosition { interstitial.skipButtonPosition = v }
            if let v = skipDelay { interstitial.skipDelay = v }
            if let v = isAutoCloseOnCompletionEnabled { interstitial.isAutoCloseOnCompletionEnabled = v }
        }
    }
}

