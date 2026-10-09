import Flutter
import UIKit
import PrebidMobile
import PrebidMobileGAMEventHandlers

class GamRewardedManager: NSObject, RewardedAdUnitDelegate {

    private let channel: FlutterMethodChannel
    private var ads: [Int: RewardedAdUnit] = [:]
    private var adIdByUnit: [ObjectIdentifier: Int] = [:]

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_gam/rewarded",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result)
        }
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let adId = args?["adId"] as? Int

        switch call.method {
        case "load":
            guard let adId = adId else {
                result(FlutterError(code: "no_ad_id", message: "Missing adId", details: nil))
                return
            }
            // Reloading an adId replaces its previous ad unit.
            release(adId)
            let configId = args?["configId"] as? String ?? ""
            let gamAdUnitId = args?["gamAdUnitId"] as? String ?? ""

            let eventHandler = GAMRewardedAdEventHandler(adUnitID: gamAdUnitId)
            if let targeting = gamCustomTargeting(args?["customTargeting"]) {
                // Prebid 3.4: app custom targeting on the GAM request; Prebid's
                // hb_* keys still take precedence.
                eventHandler.adManagerRequestConfiguration = { request in
                    var merged = request.customTargeting ?? [:]
                    targeting.forEach { merged[$0.key] = $0.value }
                    request.customTargeting = merged
                }
            }
            let adUnit = RewardedAdUnit(configID: configId, eventHandler: eventHandler)
            FullscreenControls(args?["controls"])?.apply(to: adUnit)
            applyVideoParameters(args?["videoParameters"], to: adUnit.videoParameters)
            adUnit.delegate = self

            ads[adId] = adUnit
            adIdByUnit[ObjectIdentifier(adUnit)] = adId
            adUnit.loadAd()
            result(nil)

        case "show":
            guard let adId = adId else {
                result(FlutterError(code: "no_ad_id", message: "Missing adId", details: nil))
                return
            }
            guard let adUnit = ads[adId], adUnit.isReady else {
                sendFailure(adId, "The rewarded ad is not ready to show; wait for onAdLoaded")
                result(nil)
                return
            }
            if let controller = topViewController() {
                adUnit.show(from: controller)
            } else {
                sendFailure(adId, "No view controller to present the rewarded ad from")
            }
            result(nil)

        case "destroy":
            if let adId = adId {
                release(adId)
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Drops the ad unit for `adId` and its reverse mapping, so late delegate
    /// callbacks from it are no longer forwarded.
    private func release(_ adId: Int) {
        if let adUnit = ads.removeValue(forKey: adId) {
            adIdByUnit.removeValue(forKey: ObjectIdentifier(adUnit))
        }
    }

    private func sendFailure(_ adId: Int, _ error: String) {
        channel.invokeMethod("onAdFailed", arguments: ["adId": adId, "error": error])
    }

    private func send(_ rewarded: RewardedAdUnit, _ event: String, payload: [String: Any] = [:]) {
        guard let adId = adIdByUnit[ObjectIdentifier(rewarded)] else { return }
        var data = payload
        data["adId"] = adId
        channel.invokeMethod(event, arguments: data)
    }

    func rewardedAdDidReceiveAd(_ rewardedAd: RewardedAdUnit) {
        send(rewardedAd, "onAdLoaded")
    }

    func rewardedAd(_ rewardedAd: RewardedAdUnit, didFailToReceiveAdWithError error: Error?) {
        send(rewardedAd, "onAdFailed", payload: ["error": error?.localizedDescription ?? "Unknown error"])
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
        send(rewardedAd, "onUserEarnedReward", payload: [
            "rewardType": reward.type ?? "reward",
            "rewardCount": reward.count?.intValue ?? 1,
            "rewardExt": reward.ext.flatMap { ext in
                (try? JSONSerialization.data(withJSONObject: ext)).flatMap { String(data: $0, encoding: .utf8) }
            } as Any,
        ])
    }
}
