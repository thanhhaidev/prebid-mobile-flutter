import Flutter
import UIKit
import PrebidMobile
import PrebidMobileMAXAdapters
import AppLovinSDK

/// Handles MAX-mediated interstitials over the
/// `prebid_mobile_sdk_max/interstitial` method channel. Each ad is keyed by an
/// `adId` allocated on the Dart side; native events are pushed back over the
/// same channel.
class MaxInterstitialManager: NSObject, MAAdDelegate {

    private let channel: FlutterMethodChannel

    private var adUnits: [Int: MediationInterstitialAdUnit] = [:]
    private var mediationDelegates: [Int: MAXMediationInterstitialUtils] = [:]
    private var interstitials: [Int: MAInterstitialAd] = [:]

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
            let configId = args?["configId"] as? String ?? ""
            let maxAdUnitId = args?["maxAdUnitId"] as? String ?? ""
            let isVideo = args?["isVideo"] as? Bool ?? false

            // 1. Create the MAX interstitial + Prebid mediation utils + ad unit.
            let interstitial = MAInterstitialAd(adUnitIdentifier: maxAdUnitId)
            let mediationDelegate = MAXMediationInterstitialUtils(interstitialAd: interstitial)
            let adUnit = MediationInterstitialAdUnit(
                configId: configId,
                mediationDelegate: mediationDelegate
            )
            adUnit.adFormats = isVideo ? [.video] : [.banner]

            interstitial.delegate = self
            adUnits[adId] = adUnit
            mediationDelegates[adId] = mediationDelegate
            interstitials[adId] = interstitial

            // 2. Fetch demand, then load the MAX interstitial.
            adUnit.fetchDemand { [weak self] _ in
                self?.interstitials[adId]?.load()
            }
            result(nil)

        case "show":
            if let adId = adId, let interstitial = interstitials[adId], interstitial.isReady {
                interstitial.show()
            }
            result(nil)

        case "destroy":
            if let adId = adId {
                interstitials.removeValue(forKey: adId)
                adUnits.removeValue(forKey: adId)
                mediationDelegates.removeValue(forKey: adId)
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func send(_ adId: Int, _ event: String, error: String? = nil) {
        var payload: [String: Any] = ["adId": adId]
        if let error = error {
            payload["error"] = error
        }
        channel.invokeMethod(event, arguments: payload)
    }

    // MARK: - MAAdDelegate

    func didLoad(_ ad: MAAd) {
        // MAAd does not carry the ad unit instance; resolve by unit identifier.
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

    /// Resolves the owning `adId` from a MAX ad unit identifier.
    private func adId(forAdUnitIdentifier identifier: String) -> Int? {
        for (adId, interstitial) in interstitials
        where interstitial.adUnitIdentifier == identifier {
            return adId
        }
        return nil
    }
}
