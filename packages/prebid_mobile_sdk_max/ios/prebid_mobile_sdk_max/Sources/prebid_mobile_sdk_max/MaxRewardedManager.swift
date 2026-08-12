import Flutter
import UIKit
import PrebidMobile
import PrebidMobileMAXAdapters
import AppLovinSDK

/// Handles MAX-mediated rewarded ads over the `prebid_mobile_sdk_max/rewarded`
/// method channel. Each ad is keyed by an `adId` allocated on the Dart side;
/// native events (including the reward) are pushed back over the same channel.
class MaxRewardedManager: NSObject, MARewardedAdDelegate {

    private let channel: FlutterMethodChannel

    private var adUnits: [Int: MediationRewardedAdUnit] = [:]
    private var mediationDelegates: [Int: MAXMediationRewardedUtils] = [:]
    private var rewardedAds: [Int: MARewardedAd] = [:]

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_max/rewarded",
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
            let maxAdUnitId = args?["maxAdUnitId"] as? String ?? ""

            let rewarded = MARewardedAd.shared(withAdUnitIdentifier: maxAdUnitId)
            let mediationDelegate = MAXMediationRewardedUtils(rewardedAd: rewarded)
            let adUnit = MediationRewardedAdUnit(
                configId: configId,
                mediationDelegate: mediationDelegate
            )
            rewarded.delegate = self
            adUnits[adId] = adUnit
            mediationDelegates[adId] = mediationDelegate
            rewardedAds[adId] = rewarded

            adUnit.fetchDemand { [weak self] _ in
                self?.rewardedAds[adId]?.load()
            }
            result(nil)

        case "show":
            if let adId = adId, let rewarded = rewardedAds[adId], rewarded.isReady {
                rewarded.show()
            }
            result(nil)

        case "destroy":
            if let adId = adId {
                rewardedAds.removeValue(forKey: adId)
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

    /// Resolves the owning `adId` from a MAX ad unit identifier.
    private func adId(forAdUnitIdentifier identifier: String) -> Int? {
        for (adId, ad) in rewardedAds where ad.adUnitIdentifier == identifier {
            return adId
        }
        return nil
    }

    // MARK: - MARewardedAdDelegate

    func didLoad(_ ad: MAAd) {
        if let adId = adId(forAdUnitIdentifier: ad.adUnitIdentifier) {
            send(adId, "onAdLoaded")
        }
    }

    func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        if let adId = adId(forAdUnitIdentifier: adUnitIdentifier) {
            send(adId, "onAdFailed", error: error.message)
        }
    }

    func didDisplay(_ ad: MAAd) {
        if let adId = adId(forAdUnitIdentifier: ad.adUnitIdentifier) {
            send(adId, "onAdDisplayed")
        }
    }

    func didHide(_ ad: MAAd) {
        if let adId = adId(forAdUnitIdentifier: ad.adUnitIdentifier) {
            send(adId, "onAdClosed")
        }
    }

    func didClick(_ ad: MAAd) {
        if let adId = adId(forAdUnitIdentifier: ad.adUnitIdentifier) {
            send(adId, "onAdClicked")
        }
    }

    func didFail(toDisplay ad: MAAd, withError error: MAError) {
        if let adId = adId(forAdUnitIdentifier: ad.adUnitIdentifier) {
            send(adId, "onAdFailed", error: error.message)
        }
    }

    func didRewardUser(for ad: MAAd, with reward: MAReward) {
        if let adId = adId(forAdUnitIdentifier: ad.adUnitIdentifier) {
            send(
                adId,
                "onUserEarnedReward",
                extra: ["type": reward.label, "count": reward.amount]
            )
        }
    }
}
