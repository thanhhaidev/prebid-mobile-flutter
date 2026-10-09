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
            // Reloading an adId replaces its previous ad.
            release(adId)
            let configId = args?["configId"] as? String ?? ""
            let adMobAdUnitId = args?["adMobAdUnitId"] as? String ?? ""

            let request = Request()
            let mediationDelegate = AdMobMediationRewardedUtils(gadRequest: request)
            let adUnit = MediationRewardedAdUnit(
                configId: configId,
                mediationDelegate: mediationDelegate
            )
            FullscreenControls(args?["controls"])?.apply(to: adUnit)
            applyVideoParameters(args?["videoParameters"], to: adUnit.videoParameters)
            adUnits[adId] = adUnit
            mediationDelegates[adId] = mediationDelegate

            adUnit.fetchDemand { [weak self, weak adUnit] _ in
                // Destroyed / replaced while the auction ran: skip the load.
                guard let self = self, let adUnit = adUnit, self.adUnits[adId] === adUnit else { return }
                RewardedAd.load(with: adMobAdUnitId, request: request) { [weak self, weak adUnit] ad, error in
                    // A late load must not re-insert an ad for a released adId.
                    guard let self = self, let adUnit = adUnit, self.adUnits[adId] === adUnit else { return }
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
            guard let adId = adId else {
                result(FlutterError(code: "no_ad_id", message: "Missing adId", details: nil))
                return
            }
            guard let ad = rewardedAds[adId] else {
                send(adId, "onAdFailed", error: "The rewarded ad is not ready to show; wait for onAdLoaded")
                result(nil)
                return
            }
            guard let controller = topViewController() else {
                send(adId, "onAdFailed", error: "No view controller to present the rewarded ad from")
                result(nil)
                return
            }
            ad.present(from: controller) { [weak self, weak ad] in
                guard let reward = ad?.adReward else { return }
                // Same reward keys as the GAM / MAX packages.
                self?.send(
                    adId,
                    "onUserEarnedReward",
                    extra: ["rewardType": reward.type, "rewardCount": reward.amount.intValue]
                )
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

    /// Drops everything held for `adId` (including the reverse map), so late
    /// callbacks from the released ad are no longer forwarded.
    private func release(_ adId: Int) {
        if let ad = rewardedAds.removeValue(forKey: adId) {
            ad.fullScreenContentDelegate = nil
            adIdByAd.removeValue(forKey: ObjectIdentifier(ad))
        }
        adUnits.removeValue(forKey: adId)
        mediationDelegates.removeValue(forKey: adId)
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

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        if let adId = adIdByAd[ObjectIdentifier(ad as AnyObject)] {
            send(adId, "onAdImpression")
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
