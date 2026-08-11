import Flutter
import UIKit
import PrebidMobile
import PrebidMobileGAMEventHandlers

/// Handles GAM-rendered interstitials over the `prebid_mobile_sdk_gam/interstitial`
/// method channel. Each ad is keyed by an `adId` allocated on the Dart side;
/// native events are pushed back over the same channel.
class GamInterstitialManager: NSObject, InterstitialAdUnitDelegate {

    private let channel: FlutterMethodChannel
    private var ads: [Int: InterstitialRenderingAdUnit] = [:]
    private var adIdByUnit: [ObjectIdentifier: Int] = [:]

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_gam/interstitial",
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

            let eventHandler = GAMInterstitialEventHandler(adUnitID: gamAdUnitId)
            let adUnit = InterstitialRenderingAdUnit(configID: configId, eventHandler: eventHandler)
            adUnit.adFormats = [.banner]
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

    private func send(_ interstitial: InterstitialRenderingAdUnit, _ event: String, error: String? = nil) {
        guard let adId = adIdByUnit[ObjectIdentifier(interstitial)] else { return }
        var payload: [String: Any] = ["adId": adId]
        if let error = error {
            payload["error"] = error
        }
        channel.invokeMethod(event, arguments: payload)
    }

    // MARK: - InterstitialAdUnitDelegate

    func interstitialDidReceiveAd(_ interstitial: InterstitialRenderingAdUnit) {
        send(interstitial, "onAdLoaded")
    }

    func interstitial(_ interstitial: InterstitialRenderingAdUnit, didFailToReceiveAdWithError error: Error?) {
        send(interstitial, "onAdFailed", error: error?.localizedDescription ?? "Unknown error")
    }

    func interstitialWillPresentAd(_ interstitial: InterstitialRenderingAdUnit) {
        send(interstitial, "onAdDisplayed")
    }

    func interstitialDidDismissAd(_ interstitial: InterstitialRenderingAdUnit) {
        send(interstitial, "onAdClosed")
    }

    func interstitialDidClickAd(_ interstitial: InterstitialRenderingAdUnit) {
        send(interstitial, "onAdClicked")
    }
}
