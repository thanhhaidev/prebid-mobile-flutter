import Flutter
import UIKit
import PrebidMobile
import PrebidMobileMAXAdapters
import AppLovinSDK

/// Handles MAX-mediated rewarded ads over the `prebid_mobile_sdk_max/rewarded`
/// method channel. Each ad is keyed by an `adId` allocated on the Dart side;
/// native events (including the reward) are pushed back over the same channel.
///
/// MAX hands out one shared `MARewardedAd` per ad unit, so at most one `adId`
/// owns a unit at a time: a new load on the same unit takes it over (the
/// previous owner gets `onAdFailed`), and only the owner's events are routed.
class MaxRewardedManager: NSObject {

    private let channel: FlutterMethodChannel

    private var adUnits: [Int: MediationRewardedAdUnit] = [:]
    private var mediationDelegates: [Int: MAXMediationRewardedUtils] = [:]
    private var rewardedAds: [Int: MARewardedAd] = [:]
    private var proxies: [Int: MaxAdEventProxy] = [:]
    /// MAX ad unit identifier → the `adId` that currently owns its shared ad.
    private var ownerByUnit: [String: Int] = [:]

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
            // Reloading an adId replaces its previous ad.
            release(adId)
            let configId = args?["configId"] as? String ?? ""
            let maxAdUnitId = args?["maxAdUnitId"] as? String ?? ""

            // The shared instance moves to this adId; the previous owner stops
            // receiving events and is told why.
            if let previous = ownerByUnit[maxAdUnitId], previous != adId {
                release(previous)
                send(previous, "onAdFailed", ["error": "Replaced by another ad on the same MAX ad unit"])
            }

            let rewarded = MARewardedAd.shared(withAdUnitIdentifier: maxAdUnitId)
            let mediationDelegate = MAXMediationRewardedUtils(rewardedAd: rewarded)
            let adUnit = MediationRewardedAdUnit(
                configId: configId,
                mediationDelegate: mediationDelegate
            )
            FullscreenControls(args?["controls"])?.apply(to: adUnit)
            let proxy = MaxAdEventProxy { [weak self] event, payload in
                self?.send(adId, event, payload)
            }
            rewarded.delegate = proxy
            rewarded.revenueDelegate = proxy
            adUnits[adId] = adUnit
            mediationDelegates[adId] = mediationDelegate
            rewardedAds[adId] = rewarded
            proxies[adId] = proxy
            ownerByUnit[maxAdUnitId] = adId

            adUnit.fetchDemand { [weak self, weak adUnit] _ in
                // Destroyed / replaced while the auction ran: skip the load.
                guard let self = self, let adUnit = adUnit,
                      self.adUnits[adId] === adUnit else { return }
                self.rewardedAds[adId]?.load()
            }
            result(nil)

        case "show":
            guard let adId = adId else {
                result(FlutterError(code: "no_ad_id", message: "Missing adId", details: nil))
                return
            }
            guard let rewarded = rewardedAds[adId], rewarded.isReady else {
                send(adId, "onAdFailed", ["error": "The rewarded ad is not ready to show; wait for onAdLoaded"])
                result(nil)
                return
            }
            guard let controller = topViewController() else {
                send(adId, "onAdFailed", ["error": "No view controller to present the rewarded ad from"])
                result(nil)
                return
            }
            rewarded.show(forPlacement: nil, customData: nil, viewController: controller)
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

    /// Drops everything held for `adId`. The shared MAX ad is only detached
    /// when `adId` still owns its unit — a replaced ad must not touch the
    /// instance (and delegates) the new owner is using.
    private func release(_ adId: Int) {
        if let rewarded = rewardedAds.removeValue(forKey: adId),
           ownerByUnit[rewarded.adUnitIdentifier] == adId {
            ownerByUnit.removeValue(forKey: rewarded.adUnitIdentifier)
            rewarded.delegate = nil
            rewarded.revenueDelegate = nil
        }
        proxies.removeValue(forKey: adId)
        adUnits.removeValue(forKey: adId)
        mediationDelegates.removeValue(forKey: adId)
    }

    private func send(_ adId: Int, _ event: String, _ extra: [String: Any] = [:]) {
        var payload: [String: Any] = ["adId": adId]
        payload.merge(extra) { _, new in new }
        channel.invokeMethod(event, arguments: payload)
    }
}
