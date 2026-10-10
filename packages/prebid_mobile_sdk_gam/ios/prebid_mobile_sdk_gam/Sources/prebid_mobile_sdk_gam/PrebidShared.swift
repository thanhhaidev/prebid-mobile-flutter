import Foundation
import CoreGraphics
import UIKit
import PrebidMobile

// This package's own helpers; the parsing every companion shares is in
// PrebidRequests.

/// Interstitial formats: `adFormats` (`AdFormat` names) when it names any,
/// else video or banner from `isVideo`.
func adFormatsFrom(_ raw: Any?, isVideo: Bool) -> Set<PrebidMobile.AdFormat> {
    let names = raw as? [String] ?? []
    // Qualified: GoogleMobileAds also has an `AdFormat`.
    var formats = Set<PrebidMobile.AdFormat>()
    if names.contains("banner") { formats.insert(.banner) }
    if names.contains("video") { formats.insert(.video) }
    return formats.isEmpty ? (isVideo ? [.video] : [.banner]) : formats
}

extension FullscreenControls {
    func apply(to adUnit: InterstitialRenderingAdUnit) {
        if let v = closeButtonArea { adUnit.closeButtonArea = v }
        if let v = closeButtonPosition { adUnit.closeButtonPosition = v }
        if let v = skipButtonArea { adUnit.skipButtonArea = v }
        if let v = skipButtonPosition { adUnit.skipButtonPosition = v }
        if let v = skipDelay { adUnit.skipDelay = v }
        if let v = isMuted { adUnit.isMuted = v }
        if let v = isSoundButtonVisible { adUnit.isSoundButtonVisible = v }
        if let v = isAutoCloseOnCompletionEnabled { adUnit.isAutoCloseOnCompletionEnabled = v }
        if let v = supportSKOverlay { adUnit.supportSKOverlay = v }
    }

    // Prebid iOS rewarded has no skip-button controls.
    func apply(to adUnit: RewardedAdUnit) {
        if let v = closeButtonArea { adUnit.closeButtonArea = v }
        if let v = closeButtonPosition { adUnit.closeButtonPosition = v }
        if let v = isMuted { adUnit.isMuted = v }
        if let v = isSoundButtonVisible { adUnit.isSoundButtonVisible = v }
        if let v = supportSKOverlay { adUnit.supportSKOverlay = v }
    }
}

/// The result-code names the core prebid_mobile_sdk Dart API uses (matching
/// the Android mapping), so both platforms report the same strings.
extension ResultCode {
    var dartCode: String {
        switch self {
        case .prebidDemandFetchSuccess: return "prebidDemandFetchSuccess"
        case .prebidServerNotSpecified: return "prebidServerNotSpecified"
        case .prebidInvalidAccountId: return "prebidInvalidAccountId"
        case .prebidInvalidConfigId: return "prebidInvalidConfigId"
        case .prebidInvalidSize: return "prebidInvalidSize"
        case .prebidNetworkError: return "prebidNetworkError"
        case .prebidServerError: return "prebidServerError"
        case .prebidDemandNoBids: return "prebidDemandNoBids"
        case .prebidDemandTimedOut: return "prebidDemandTimedOut"
        case .prebidServerURLInvalid: return "prebidServerURLInvalid"
        case .prebidDemandNoCachedBids: return "prebidDemandNoCachedBids"
        case .prebidUnknownError: return "prebidUnknownError"
        case .prebidInvalidResponseStructure: return "prebidInvalidResponseStructure"
        case .prebidInternalSDKError: return "prebidInternalSDKError"
        case .prebidWrongArguments: return "prebidWrongArguments"
        case .prebidNoVastTagInMediaData: return "prebidNoVastTagInMediaData"
        case .prebidSDKMisuse, .prebidSDKMisusePreviousFetchNotCompletedYet: return "prebidSDKMisuse"
        default: return "prebidInvalidRequest"
        }
    }
}

