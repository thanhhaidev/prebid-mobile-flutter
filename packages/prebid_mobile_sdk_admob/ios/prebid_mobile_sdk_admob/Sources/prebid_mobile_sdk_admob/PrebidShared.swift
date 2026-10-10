import Foundation
import CoreGraphics
import UIKit
import GoogleMobileAds
import PrebidMobile
import PrebidMobileAdMobAdapters

// This package's own helpers; the parsing every companion shares is in
// PrebidRequests.

/// Runs `block` on the main thread: method channels must be called there,
/// and some SDK completions arrive on background queues.
func onMain(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.async(execute: block)
    }
}

/// The method-channel suffix of a platform view: the `channelId` creation
/// param the Dart widget listens on before the view exists (falls back to the
/// platform view id).
func viewChannelId(_ args: [String: Any], viewId: Int64) -> Int64 {
    (args["channelId"] as? NSNumber)?.int64Value ?? viewId
}

/// `debugDropBidProbability` (`PrebidAdMob.debugDropBidProbability`, testing
/// only), clamped to `0...1`; 0 when absent.
func debugDropBidProbability(_ raw: Any?) -> Double {
    guard let p = (raw as? NSNumber)?.doubleValue, !p.isNaN else { return 0 }
    return min(max(p, 0), 1)
}

/// Testing hook: with `probability`, drops the Prebid bid from `request` after
/// `fetchDemand` so the Prebid AdMob adapter finds no bid and AdMob falls back
/// to its waterfall. Prebid iOS has no bid cache to pop (Android's test app
/// pops `BidResponseCache`): the bid travels in the request's custom-event
/// extras, so those are cleared — as the mediation utils' `cleanUpAdObject`
/// does — while the `hb_*` keywords stay and still pick the Prebid line.
func maybeDropBid(_ probability: Double, from request: GoogleMobileAds.Request) {
    guard probability > 0, Double.random(in: 0..<1) < probability else { return }
    let extras = GoogleMobileAds.CustomEventExtras()
    extras.setExtras(nil, forLabel: AdMobConstants.PrebidAdMobEventExtrasLabel)
    request.register(extras)
}

/// Ad unit formats: `adFormats` (`PrebidAdFormat` names) when it names any,
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

