import Flutter
import UIKit
import PrebidMobile
import PrebidMobileGAMEventHandlers

/// GAM-rendered rewarded ads over the `prebid_mobile_sdk_gam/rewarded` method
/// channel.
final class GamRewardedManager: FullscreenAdManager, RewardedAdUnitDelegate {

    init(messenger: FlutterBinaryMessenger) {
        super.init(name: "prebid_mobile_sdk_gam/rewarded", messenger: messenger)
    }

    override func makeAdUnit(args: [String: Any]) -> FullscreenAdUnit {
        let configId = args["configId"] as? String ?? ""
        let gamAdUnitId = args["gamAdUnitId"] as? String ?? ""

        let eventHandler = GAMRewardedAdEventHandler(adUnitID: gamAdUnitId)
        if let targeting = gamCustomTargeting(args["customTargeting"]) {
            // Prebid 3.4: app custom targeting on the GAM request; Prebid's
            // hb_* keys still take precedence.
            eventHandler.adManagerRequestConfiguration = { request in
                var merged = request.customTargeting ?? [:]
                targeting.forEach { merged[$0.key] = $0.value }
                request.customTargeting = merged
            }
        }
        let controls = FullscreenControls(args["controls"])
        let adUnit: RewardedAdUnit
        if let minSize = controls?.minSizePercentage {
            adUnit = RewardedAdUnit(configID: configId, minSizePercentage: minSize, eventHandler: eventHandler)
        } else {
            adUnit = RewardedAdUnit(configID: configId, eventHandler: eventHandler)
        }
        controls?.apply(to: adUnit)
        applyVideoParameters(args["videoParameters"], to: adUnit.videoParameters)
        if let config = args["impOrtbConfig"] as? String { adUnit.setImpORTBConfig(config) }
        adUnit.delegate = self
        return adUnit
    }

    // MARK: - RewardedAdUnitDelegate

    func rewardedAdDidReceiveAd(_ rewardedAd: RewardedAdUnit) {
        send(rewardedAd, "onAdLoaded")
    }

    func rewardedAd(_ rewardedAd: RewardedAdUnit, didFailToReceiveAdWithError error: Error?) {
        send(rewardedAd, "onAdFailed", error: PrebidErrorFormatter.describe(error))
    }

    func rewardedAdWillPresentAd(_ rewardedAd: RewardedAdUnit) {
        send(rewardedAd, "onAdDisplayed")
    }

    func rewardedAdDidDismissAd(_ rewardedAd: RewardedAdUnit) {
        send(rewardedAd, "onAdClosed")
    }

    func rewardedAdDidClickAd(_ rewardedAd: RewardedAdUnit) {
        send(rewardedAd, "onAdClicked")
    }

    func rewardedAdDidExpire(_ rewardedAd: RewardedAdUnit) {
        send(rewardedAd, "onAdExpired")
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
        send(rewardedAd, "onUserEarnedReward", extras: payload)
    }
}
