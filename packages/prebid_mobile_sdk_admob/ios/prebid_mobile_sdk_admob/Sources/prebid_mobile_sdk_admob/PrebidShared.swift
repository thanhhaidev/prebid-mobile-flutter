import Foundation
import CoreGraphics
import UIKit
import PrebidMobile

// Helpers for the values the Dart side sends over method channels:
// `NativeAsset.toMap()`, `NativeEventTracker.toMap()` and
// `PrebidFullscreenControls.toMap()` from prebid_mobile_sdk.

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
