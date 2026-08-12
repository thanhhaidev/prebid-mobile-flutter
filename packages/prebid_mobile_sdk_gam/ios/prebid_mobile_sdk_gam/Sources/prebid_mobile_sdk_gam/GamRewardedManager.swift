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
            let configId = args?["configId"] as? String ?? ""
            let gamAdUnitId = args?["gamAdUnitId"] as? String ?? ""

            let eventHandler = GAMRewardedAdEventHandler(adUnitID: gamAdUnitId)
            let adUnit = RewardedAdUnit(configID: configId, eventHandler: eventHandler)
            adUnit.delegate = self

            ads[adId] = adUnit
            adIdByUnit[ObjectIdentifier(adUnit)] = adId
            adUnit.loadAd()
            result(nil)

        case "show":
            if let adId = adId,
               let adUnit = ads[adId],
               let root = UIApplication.shared.keyWindow?.rootViewController {
                adUnit.show(from: root)
            }
            result(nil)

        case "destroy":
            if let adId = adId, let adUnit = ads.removeValue(forKey: adId) {
                adIdByUnit.removeValue(forKey: ObjectIdentifier(adUnit))
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
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

    func rewardedAdUserDidEarnReward(_ rewardedAd: RewardedAdUnit) {
        send(rewardedAd, "onUserEarnedReward", payload: ["rewardType": "reward", "rewardCount": 1])
    }
}
