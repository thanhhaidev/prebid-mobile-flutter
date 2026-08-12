import Flutter
import UIKit
import GoogleMobileAds
import PrebidMobile
import PrebidMobileAdMobAdapters

/// Handles AdMob-mediated rewarded ads over the
/// `prebid_mobile_sdk_admob/rewarded` method channel. Each ad is keyed by an
/// `adId` allocated on the Dart side; native events (including the reward) are
/// pushed back over the same channel.
class AdMobRewardedManager: NSObject, FullScreenContentDelegate {

    private let channel: FlutterMethodChannel

    private var adUnits: [Int: MediationRewardedAdUnit] = [:]
    private var mediationDelegates: [Int: AdMobMediationRewardedUtils] = [:]
    private var rewardedAds: [Int: RewardedAd] = [:]
    private var adIdByAd: [ObjectIdentifier: Int] = [:]

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_admob/rewarded",
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
            let adMobAdUnitId = args?["adMobAdUnitId"] as? String ?? ""

            let request = Request()
            let mediationDelegate = AdMobMediationRewardedUtils(gadRequest: request)
            let adUnit = MediationRewardedAdUnit(
                configId: configId,
                mediationDelegate: mediationDelegate
            )
            adUnits[adId] = adUnit
            mediationDelegates[adId] = mediationDelegate

            adUnit.fetchDemand { [weak self] _ in
                RewardedAd.load(with: adMobAdUnitId, request: request) { [weak self] ad, error in
                    guard let self = self else { return }
                    if let error = error {
                        self.send(adId, "onAdFailed", error: error.localizedDescription)
                        return
                    }
                    guard let ad = ad else { return }
                    ad.fullScreenContentDelegate = self
                    self.rewardedAds[adId] = ad
                    self.adIdByAd[ObjectIdentifier(ad)] = adId
                    self.send(adId, "onAdLoaded")
                }
            }
            result(nil)

        case "show":
            if let adId = adId,
               let ad = rewardedAds[adId],
               let root = UIApplication.shared.keyWindow?.rootViewController {
                ad.present(from: root) { [weak self] in
                    let reward = ad.adReward
                    self?.send(
                        adId,
                        "onUserEarnedReward",
                        extra: ["type": reward.type, "count": reward.amount.intValue]
                    )
                }
            }
            result(nil)

        case "destroy":
            if let adId = adId {
                if let ad = rewardedAds.removeValue(forKey: adId) {
                    adIdByAd.removeValue(forKey: ObjectIdentifier(ad))
                }
                adUnits.removeValue(forKey: adId)
                mediationDelegates.removeValue(forKey: adId)
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func send(_ adId: Int, _ event: String, error: String? = nil, extra: [String: Any]? = nil) {
        var payload: [String: Any] = ["adId": adId]
        if let error = error {
            payload["error"] = error
        }
        if let extra = extra {
            payload.merge(extra) { _, new in new }
        }
        channel.invokeMethod(event, arguments: payload)
    }

    // MARK: - FullScreenContentDelegate

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        if let adId = adIdByAd[ObjectIdentifier(ad as AnyObject)] {
            send(adId, "onAdDisplayed")
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if let adId = adIdByAd[ObjectIdentifier(ad as AnyObject)] {
            send(adId, "onAdClosed")
        }
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        if let adId = adIdByAd[ObjectIdentifier(ad as AnyObject)] {
            send(adId, "onAdClicked")
        }
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        if let adId = adIdByAd[ObjectIdentifier(ad as AnyObject)] {
            send(adId, "onAdFailed", error: error.localizedDescription)
        }
    }
}
