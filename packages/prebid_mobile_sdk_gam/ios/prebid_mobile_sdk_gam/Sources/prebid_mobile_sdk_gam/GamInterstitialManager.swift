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
            // Reloading an adId replaces its previous ad unit.
            release(adId)
            let configId = args?["configId"] as? String ?? ""
            let gamAdUnitId = args?["gamAdUnitId"] as? String ?? ""
            let requestedFormats = args?["adFormats"] as? [String] ?? ["banner"]

            let eventHandler = GAMInterstitialEventHandler(adUnitID: gamAdUnitId)
            if let targeting = gamCustomTargeting(args?["customTargeting"]) {
                // Prebid 3.4: app custom targeting on the GAM request; Prebid's
                // hb_* keys still take precedence.
                eventHandler.adManagerRequestConfiguration = { request in
                    var merged = request.customTargeting ?? [:]
                    targeting.forEach { merged[$0.key] = $0.value }
                    request.customTargeting = merged
                }
            }
            let controls = FullscreenControls(args?["controls"])
            let adUnit: InterstitialRenderingAdUnit
            if let minSize = controls?.minSizePercentage {
                adUnit = InterstitialRenderingAdUnit(
                    configID: configId, minSizePercentage: minSize, eventHandler: eventHandler
                )
            } else {
                adUnit = InterstitialRenderingAdUnit(configID: configId, eventHandler: eventHandler)
            }
            controls?.apply(to: adUnit)
            var formats: Set<AdFormat> = []
            if requestedFormats.contains("banner") { formats.insert(.banner) }
            if requestedFormats.contains("video") { formats.insert(.video) }
            adUnit.adFormats = formats.isEmpty ? [.banner] : formats
            applyVideoParameters(args?["videoParameters"], to: adUnit.videoParameters)
            if let config = args?["impOrtbConfig"] as? String { adUnit.setImpORTBConfig(config) }
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
                sendFailure(adId, "The interstitial is not ready to show; wait for onAdLoaded")
                result(nil)
                return
            }
            if let controller = topViewController() {
                adUnit.show(from: controller)
            } else {
                sendFailure(adId, "No view controller to present the interstitial from")
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

    func interstitialDidExpireAd(_ interstitial: InterstitialRenderingAdUnit) {
        send(interstitial, "onAdExpired")
    }
}
