import CoreGraphics
import Foundation
import GoogleMobileAds
import PrebidMobile
import PrebidMobileAdMobAdapters
import UIKit

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
