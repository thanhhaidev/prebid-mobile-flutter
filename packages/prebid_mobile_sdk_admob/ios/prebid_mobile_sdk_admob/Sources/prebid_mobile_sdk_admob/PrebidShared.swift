import Foundation
import CoreGraphics
import UIKit
import GoogleMobileAds
import PrebidMobile
import PrebidMobileAdMobAdapters

// This package's own helpers; what every companion shares is in
// PrebidPlugin and PrebidRequests.

/// Testing hook: with `probability`, drops the Prebid bid from `request` after
/// `fetchDemand` so the Prebid AdMob adapter finds no bid and AdMob falls back
/// to its waterfall. Prebid iOS has no bid cache to pop (Android's test app
/// pops `BidResponseCache`): the bid travels in the request's custom-event
/// extras, so those are cleared — as the mediation utils' `cleanUpAdObject`
/// does — while the `hb_*` keywords stay and still pick the Prebid line.
func maybeDropBid(_ probability: Double, from request: GoogleMobileAds.Request) {
    guard shouldDropBid(probability) else { return }
    let extras = GoogleMobileAds.CustomEventExtras()
    extras.setExtras(nil, forLabel: AdMobConstants.PrebidAdMobEventExtrasLabel)
    request.register(extras)
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

