import Foundation
import CoreGraphics
import Flutter
import UIKit
import PrebidMobile
import AppLovinSDK

// This package's own helpers; the parsing every companion shares is in
// PrebidRequests.

extension PrebidErrorFormatter {
    /// A MAX error's message (`MAError` is no `Error`), with the same
    /// fallback.
    static func describe(_ error: MAError?) -> String {
        guard let message = error?.message, !message.isEmpty else { return "Unknown error" }
        return message
    }
}

/// Runs `body` on the main thread: Flutter channels must be called there,
/// and not every SDK callback arrives on it.
func onMain(_ body: @escaping () -> Void) {
    if Thread.isMainThread {
        body()
    } else {
        DispatchQueue.main.async(execute: body)
    }
}

/// The method channel of a platform view: `<prefix>_<channelId>`, the id the
/// Dart widget listens on before the view exists (so a failure reported
/// during creation is not lost). Falls back to the platform view id.
func viewChannel(_ prefix: String, args: [String: Any], viewId: Int64, messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channelId = (args["channelId"] as? NSNumber)?.int64Value ?? viewId
    return FlutterMethodChannel(name: "\(prefix)_\(channelId)", binaryMessenger: messenger)
}

/// `debugDropBidProbability` (`PrebidMax.debugDropBidProbability`, testing
/// only), clamped to `0...1`; 0 when absent.
func debugDropBidProbability(_ raw: Any?) -> Double {
    guard let p = (raw as? NSNumber)?.doubleValue, !p.isNaN else { return 0 }
    return min(max(p, 0), 1)
}

/// Testing hook: whether to withhold this load's Prebid bid from MAX, with
/// `probability`. Android's test app sets the response-id local extra to ""
/// there; Prebid iOS passes the bid object itself, so the caller clears the
/// `PBMMediationAdUnitBidKey` local extra instead — the Prebid MAX adapter
/// then finds no bid and MAX falls back to its waterfall.
func shouldDropBid(_ probability: Double) -> Bool {
    probability > 0 && Double.random(in: 0..<1) < probability
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

/// `adFormats` (`PrebidAdFormat` names), or `nil` when it names none.
func adFormatsFrom(_ raw: Any?) -> Set<PrebidMobile.AdFormat>? {
    let names = raw as? [String] ?? []
    var formats = Set<PrebidMobile.AdFormat>()
    if names.contains("banner") { formats.insert(.banner) }
    if names.contains("video") { formats.insert(.video) }
    return formats.isEmpty ? nil : formats
}

/// Interstitial formats: `adFormats` when it names any, else video or banner
/// from `isVideo`.
func adFormatsFrom(_ raw: Any?, isVideo: Bool) -> Set<PrebidMobile.AdFormat> {
    adFormatsFrom(raw) ?? (isVideo ? [.video] : [.banner])
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

