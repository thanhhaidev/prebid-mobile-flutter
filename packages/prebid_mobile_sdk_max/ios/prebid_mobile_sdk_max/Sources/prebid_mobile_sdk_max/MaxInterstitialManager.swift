import Flutter
import UIKit
import PrebidMobile
import PrebidMobileMAXAdapters
import AppLovinSDK

/// Per-ad MAX delegate. `MAAd` carries only the ad unit identifier, so two ads
/// on the same unit could not be told apart by a shared delegate; each MAX ad
/// object instead gets its own proxy that already knows its `adId`. MAX holds
/// delegates weakly, so the managers retain the proxies.
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
        emit("onAdFailed", ["error": error.message])
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
        emit("onAdFailed", ["error": error.message])
    }

    // MAX reports revenue when the impression is recorded.
    func didPayRevenue(for ad: MAAd) {
        emit("onAdImpression", [:])
    }

    // Rewarded only; same reward keys as the GAM / AdMob packages.
    func didRewardUser(for ad: MAAd, with reward: MAReward) {
        emit("onUserEarnedReward", ["rewardType": reward.label, "rewardCount": reward.amount])
    }
}

/// Handles MAX-mediated interstitials over the
/// `prebid_mobile_sdk_max/interstitial` method channel. Each ad is keyed by an
/// `adId` allocated on the Dart side; native events are pushed back over the
/// same channel.
class MaxInterstitialManager: NSObject {

    private let channel: FlutterMethodChannel

    private var adUnits: [Int: MediationInterstitialAdUnit] = [:]
    private var mediationDelegates: [Int: MAXMediationInterstitialUtils] = [:]
    private var interstitials: [Int: MAInterstitialAd] = [:]
    private var proxies: [Int: MaxAdEventProxy] = [:]

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_max/interstitial",
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
            let isVideo = args?["isVideo"] as? Bool ?? false

            // 1. Create the MAX interstitial + Prebid mediation utils + ad unit.
            let interstitial = MAInterstitialAd(adUnitIdentifier: maxAdUnitId)
            let mediationDelegate = MAXMediationInterstitialUtils(interstitialAd: interstitial)
            let controls = FullscreenControls(args?["controls"])
            let adUnit = MediationInterstitialAdUnit(
                configId: configId,
                minSizePercentage: controls?.minSizePercentage,
                mediationDelegate: mediationDelegate
            )
            adUnit.adFormats = isVideo ? [.video] : [.banner]
            controls?.apply(to: adUnit)

            let proxy = MaxAdEventProxy { [weak self] event, payload in
                self?.send(adId, event, payload)
            }
            interstitial.delegate = proxy
            interstitial.revenueDelegate = proxy
            adUnits[adId] = adUnit
            mediationDelegates[adId] = mediationDelegate
            interstitials[adId] = interstitial
            proxies[adId] = proxy

            // 2. Fetch demand, then load the MAX interstitial (unless it was
            // destroyed / replaced while the auction ran).
            adUnit.fetchDemand { [weak self, weak interstitial] _ in
                guard let self = self, let interstitial = interstitial,
                      self.interstitials[adId] === interstitial else { return }
                interstitial.load()
            }
            result(nil)

        case "show":
            guard let adId = adId else {
                result(FlutterError(code: "no_ad_id", message: "Missing adId", details: nil))
                return
            }
            guard let interstitial = interstitials[adId], interstitial.isReady else {
                send(adId, "onAdFailed", ["error": "The interstitial is not ready to show; wait for onAdLoaded"])
                result(nil)
                return
            }
            guard let controller = topViewController() else {
                send(adId, "onAdFailed", ["error": "No view controller to present the interstitial from"])
                result(nil)
                return
            }
            interstitial.show(forPlacement: nil, customData: nil, viewController: controller)
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

    /// Drops everything held for `adId`; releasing the proxy detaches the
    /// (weak) MAX delegates so late callbacks are no longer forwarded.
    private func release(_ adId: Int) {
        if let interstitial = interstitials.removeValue(forKey: adId) {
            interstitial.delegate = nil
            interstitial.revenueDelegate = nil
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
