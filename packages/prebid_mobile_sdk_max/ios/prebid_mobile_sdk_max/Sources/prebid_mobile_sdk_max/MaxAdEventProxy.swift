import Foundation
import AppLovinSDK

/// Per-ad MAX delegate of the interstitial and rewarded managers. `MAAd`
/// carries only the ad unit identifier, so two ads on the same unit could not
/// be told apart by a shared delegate; each MAX ad object instead gets its own
/// proxy that already knows its `adId`. MAX holds delegates weakly, so the
/// managers retain the proxies.
final class MaxAdEventProxy: NSObject, MARewardedAdDelegate, MAAdRevenueDelegate {

    private let emit: (_ event: String, _ payload: [String: Any]) -> Void

    init(emit: @escaping (_ event: String, _ payload: [String: Any]) -> Void) {
        self.emit = emit
        super.init()
    }

    func didLoad(_ ad: MAAd) {
        emit("onAdLoaded", [:])
    }

    func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        emit("onAdFailed", ["error": PrebidErrorFormatter.describe(error)])
    }

    func didDisplay(_ ad: MAAd) {
        emit("onAdDisplayed", [:])
    }

    func didHide(_ ad: MAAd) {
        emit("onAdClosed", [:])
    }

    func didClick(_ ad: MAAd) {
        emit("onAdClicked", [:])
    }

    func didFail(toDisplay ad: MAAd, withError error: MAError) {
        emit("onAdFailed", ["error": PrebidErrorFormatter.describe(error)])
    }

    // MAX reports revenue when the impression is recorded.
    func didPayRevenue(for ad: MAAd) {
        emit("onAdImpression", [:])
        emit("onAdRevenuePaid", revenuePayload(ad))
    }

    // Rewarded only; same reward keys as the GAM / AdMob packages.
    func didRewardUser(for ad: MAAd, with reward: MAReward) {
        emit("onUserEarnedReward", ["rewardType": reward.label, "rewardCount": reward.amount])
    }
}
