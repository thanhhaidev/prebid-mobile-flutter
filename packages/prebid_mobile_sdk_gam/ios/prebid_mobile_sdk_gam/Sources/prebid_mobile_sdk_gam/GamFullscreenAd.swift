import Foundation
import UIKit
import PrebidMobile

/// What the GAM managers need from a Prebid fullscreen ad unit.
protocol GamFullscreenAdUnit: AnyObject {
    var isReady: Bool { get }
    func loadAd()
    func show(from controller: UIViewController)
}

extension InterstitialRenderingAdUnit: GamFullscreenAdUnit {}
extension RewardedAdUnit: GamFullscreenAdUnit {}

/// One GAM-rendered interstitial or rewarded ad: the Prebid ad unit and the
/// delegate forwarding its callbacks (Prebid holds the delegate weakly).
final class GamFullscreenAd {
    let adUnit: GamFullscreenAdUnit
    let events: GamFullscreenEvents

    init(adUnit: GamFullscreenAdUnit, events: GamFullscreenEvents) {
        self.adUnit = adUnit
        self.events = events
    }
}

/// Forwards a Prebid interstitial's or rewarded ad's delegate callbacks as
/// Dart events.
final class GamFullscreenEvents: NSObject, InterstitialAdUnitDelegate, RewardedAdUnitDelegate {

    /// Receives each event, its error message and payload.
    var forward: (_ event: String, _ error: String?, _ extras: [String: Any]) -> Void = { _, _, _ in }

    private func send(_ event: String, error: String? = nil, extras: [String: Any] = [:]) {
        forward(event, error, extras)
    }

    // MARK: - InterstitialAdUnitDelegate

    func interstitialDidReceiveAd(_ interstitial: InterstitialRenderingAdUnit) {
        send("onAdLoaded")
    }

    func interstitial(_ interstitial: InterstitialRenderingAdUnit, didFailToReceiveAdWithError error: Error?) {
        send("onAdFailed", error: PrebidErrorFormatter.describe(error))
    }

    func interstitialWillPresentAd(_ interstitial: InterstitialRenderingAdUnit) {
        send("onAdDisplayed")
    }

    func interstitialDidDismissAd(_ interstitial: InterstitialRenderingAdUnit) {
        send("onAdClosed")
    }

    func interstitialDidClickAd(_ interstitial: InterstitialRenderingAdUnit) {
        send("onAdClicked")
    }

    func interstitialDidExpireAd(_ interstitial: InterstitialRenderingAdUnit) {
        send("onAdExpired")
    }

    // MARK: - RewardedAdUnitDelegate

    func rewardedAdDidReceiveAd(_ rewardedAd: RewardedAdUnit) {
        send("onAdLoaded")
    }

    func rewardedAd(_ rewardedAd: RewardedAdUnit, didFailToReceiveAdWithError error: Error?) {
        send("onAdFailed", error: PrebidErrorFormatter.describe(error))
    }

    func rewardedAdWillPresentAd(_ rewardedAd: RewardedAdUnit) {
        send("onAdDisplayed")
    }

    func rewardedAdDidDismissAd(_ rewardedAd: RewardedAdUnit) {
        send("onAdClosed")
    }

    func rewardedAdDidClickAd(_ rewardedAd: RewardedAdUnit) {
        send("onAdClicked")
    }

    func rewardedAdDidExpire(_ rewardedAd: RewardedAdUnit) {
        send("onAdExpired")
    }

    func rewardedAdUserDidEarnReward(_ rewardedAd: RewardedAdUnit, reward: PrebidReward) {
        var payload: [String: Any] = [
            "rewardType": reward.type ?? "reward",
            "rewardCount": reward.count?.intValue ?? 1,
        ]
        // Omitted rather than NSNull when absent, as on Android.
        if let ext = reward.ext,
           let data = try? JSONSerialization.data(withJSONObject: ext),
           let json = String(data: data, encoding: .utf8) {
            payload["rewardExt"] = json
        }
        send("onUserEarnedReward", extras: payload)
    }
}

/// The GAM managers' common part: an ad is its Prebid ad unit, which loads,
/// shows and reports through `GamFullscreenEvents`.
class GamFullscreenAdManager: FullscreenAdManager<GamFullscreenAd> {

    /// Builds the Prebid ad unit from the `load` arguments.
    func makeAdUnit(_ args: [String: Any], delegate: GamFullscreenEvents) -> GamFullscreenAdUnit {
        preconditionFailure("Subclasses build their ad unit")
    }

    override func create(_ adId: Int, _ args: [String: Any]) -> GamFullscreenAd {
        let events = GamFullscreenEvents()
        let ad = GamFullscreenAd(adUnit: makeAdUnit(args, delegate: events), events: events)
        events.forward = { [weak self, weak ad] event, error, extras in
            guard let self = self, let ad = ad, self.isCurrent(adId, ad) else { return }
            self.send(adId, event, error: error, extras: extras)
        }
        return ad
    }

    override func load(_ adId: Int, _ ad: GamFullscreenAd) {
        ad.adUnit.loadAd()
    }

    override func isLoaded(_ ad: GamFullscreenAd) -> Bool {
        ad.adUnit.isReady
    }

    override func show(_ adId: Int, _ ad: GamFullscreenAd, from controller: UIViewController) {
        ad.adUnit.show(from: controller)
    }
}
