import Foundation
import CoreGraphics
import UIKit
import PrebidMobile

// Helpers for the values the Dart side sends over method channels:
// `NativeAsset.toMap()`, `NativeEventTracker.toMap()`,
// `PrebidFullscreenControls.toMap()` and `VideoParameters.toMap()` from
// prebid_mobile_sdk.

private func intValue(_ raw: Any?) -> Int? { (raw as? NSNumber)?.intValue }

/// The view controller to present fullscreen ads / modals from: the top-most
/// presented controller of the key window in the foreground-active scene
/// (avoids the deprecated `UIApplication.keyWindow`). `nil` when the app has
/// no foreground window yet.
func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController, !presented.isBeingDismissed {
        top = presented
    }
    return top
}

/// Native request assets, or nil when the widget uses the defaults.
func nativeAssetsFrom(_ raw: Any?) -> [NativeAsset]? {
    guard let list = raw as? [[String: Any]] else { return nil }
    return list.compactMap { m -> NativeAsset? in
        let required = m["required"] as? Bool ?? false
        switch m["assetType"] as? String {
        case "title":
            return NativeAssetTitle(length: intValue(m["titleLength"]) ?? 90, required: required)
        case "image":
            let image = NativeAssetImage(isRequired: required)
            if let t = intValue(m["imageType"]) { image.type = ImageAsset(integerLiteral: t) }
            if let w = intValue(m["imageWidth"]) { image.width = w }
            if let h = intValue(m["imageHeight"]) { image.height = h }
            if let w = intValue(m["imageWidthMin"]) { image.widthMin = w }
            if let h = intValue(m["imageHeightMin"]) { image.heightMin = h }
            return image
        case "data":
            guard let t = intValue(m["dataType"]), let type = DataAsset(rawValue: t) else { return nil }
            let data = NativeAssetData(type: type, required: required)
            if let len = intValue(m["dataLength"]) { data.length = len }
            return data
        default:
            return nil
        }
    }
}

/// Native event trackers, or nil when the widget uses the defaults.
func nativeTrackersFrom(_ raw: Any?) -> [NativeEventTracker]? {
    guard let list = raw as? [[String: Any]] else { return nil }
    return list.compactMap { m -> NativeEventTracker? in
        guard let event = intValue(m["eventType"]) else { return nil }
        let methods = (m["methods"] as? [NSNumber] ?? []).map { EventTracking(integerLiteral: $0.intValue) }
        return NativeEventTracker(event: EventType(integerLiteral: event), methods: methods)
    }
}

/// Copies `VideoParameters.toMap()` onto an ad unit's `videoParameters`, which
/// Prebid exposes get-only (it is configured in place). Absent keys keep the
/// SDK defaults.
func applyVideoParameters(_ raw: Any?, to vp: VideoParameters) {
    guard let m = raw as? [String: Any] else { return }
    func ints(_ key: String) -> [Int]? { (m[key] as? [NSNumber])?.map { $0.intValue } }

    if let mimes = m["mimes"] as? [String], !mimes.isEmpty { vp.mimes = mimes }
    if let v = ints("protocols") { vp.protocols = v.map { Signals.Protocols(integerLiteral: $0) } }
    if let v = ints("playbackMethods") { vp.playbackMethod = v.map { Signals.PlaybackMethod(integerLiteral: $0) } }
    if let v = ints("api") { vp.api = v.map { Signals.Api(integerLiteral: $0) } }
    if let v = intValue(m["placement"]) { vp.placement = Signals.Placement(integerLiteral: v) }
    if let v = intValue(m["plcmt"]) { vp.plcmnt = Signals.Plcmnt(integerLiteral: v) }
    if let v = intValue(m["startDelay"]) { vp.startDelay = Signals.StartDelay(integerLiteral: v) }
    if let v = intValue(m["linearity"]) { vp.linearity = SingleContainerInt(integerLiteral: v) }
    if let v = ints("battr") { vp.battr = v.map { Signals.CreativeAttribute(integerLiteral: $0) } }
    if let v = m["skippable"] as? Bool { vp.isSkippable = v }
    if let v = intValue(m["maxDuration"]) { vp.maxDuration = SingleContainerInt(integerLiteral: v) }
    if let v = intValue(m["minDuration"]) { vp.minDuration = SingleContainerInt(integerLiteral: v) }
    if let v = intValue(m["maxBitrate"]) { vp.maxBitrate = SingleContainerInt(integerLiteral: v) }
    if let v = intValue(m["minBitrate"]) { vp.minBitrate = SingleContainerInt(integerLiteral: v) }
}

/// Fullscreen rendering controls (`PrebidFullscreenControls`).
struct FullscreenControls {
    let closeButtonArea: Double?
    let closeButtonPosition: Position?
    let skipButtonArea: Double?
    let skipButtonPosition: Position?
    let skipDelay: Double?
    let isMuted: Bool?
    let isSoundButtonVisible: Bool?
    let isAutoCloseOnCompletionEnabled: Bool?
    let supportSKOverlay: Bool?
    let minSizePercentage: CGSize?

    init?(_ raw: Any?) {
        guard let m = raw as? [String: Any] else { return nil }
        closeButtonArea = (m["closeButtonArea"] as? NSNumber)?.doubleValue
        closeButtonPosition = FullscreenControls.position(m["closeButtonPosition"])
        skipButtonArea = (m["skipButtonArea"] as? NSNumber)?.doubleValue
        skipButtonPosition = FullscreenControls.position(m["skipButtonPosition"])
        skipDelay = (m["skipDelay"] as? NSNumber)?.doubleValue
        isMuted = m["isMuted"] as? Bool
        isSoundButtonVisible = m["isSoundButtonVisible"] as? Bool
        isAutoCloseOnCompletionEnabled = m["isAutoCloseOnCompletionEnabled"] as? Bool
        supportSKOverlay = m["supportSKOverlay"] as? Bool
        if let w = intValue(m["minWidthPercentage"]), let h = intValue(m["minHeightPercentage"]) {
            minSizePercentage = CGSize(width: w, height: h)
        } else {
            minSizePercentage = nil
        }
    }

    private static func position(_ raw: Any?) -> Position? {
        switch raw as? String {
        case "topLeft": return .topLeft
        case "topRight": return .topRight
        default: return nil
        }
    }
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
        default: return "prebidInvalidRequest"
        }
    }
}
