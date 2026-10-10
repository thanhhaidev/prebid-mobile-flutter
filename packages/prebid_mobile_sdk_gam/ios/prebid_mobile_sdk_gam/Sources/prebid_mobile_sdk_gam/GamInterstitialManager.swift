import Flutter
import UIKit
import PrebidMobile
import PrebidMobileGAMEventHandlers

/// GAM-rendered interstitials over the `prebid_mobile_sdk_gam/interstitial`
/// method channel.
final class GamInterstitialManager: FullscreenAdManager, InterstitialAdUnitDelegate {

    init(messenger: FlutterBinaryMessenger) {
        super.init(name: "prebid_mobile_sdk_gam/interstitial", messenger: messenger)
    }

    override func makeAdUnit(args: [String: Any]) -> FullscreenAdUnit {
        let configId = args["configId"] as? String ?? ""
        let gamAdUnitId = args["gamAdUnitId"] as? String ?? ""
        let isVideo = args["isVideo"] as? Bool ?? false

        let eventHandler = GAMInterstitialEventHandler(adUnitID: gamAdUnitId)
        if let targeting = gamCustomTargeting(args["customTargeting"]) {
            // Prebid 3.4: app custom targeting on the GAM request; Prebid's
            // hb_* keys still take precedence.
            eventHandler.adManagerRequestConfiguration = { request in
                var merged = request.customTargeting ?? [:]
                targeting.forEach { merged[$0.key] = $0.value }
                request.customTargeting = merged
            }
        }
        let controls = FullscreenControls(args["controls"])
        let adUnit: InterstitialRenderingAdUnit
        if let minSize = controls?.minSizePercentage {
            adUnit = InterstitialRenderingAdUnit(
                configID: configId, minSizePercentage: minSize, eventHandler: eventHandler
            )
        } else {
            adUnit = InterstitialRenderingAdUnit(configID: configId, eventHandler: eventHandler)
        }
        controls?.apply(to: adUnit)
        adUnit.adFormats = adFormatsFrom(args["adFormats"], isVideo: isVideo)
        applyVideoParameters(args["videoParameters"], to: adUnit.videoParameters)
        // Prebid iOS has no pbAdSlot setter on this ad unit: send it in the imp.
        if let config = impOrtb(args["impOrtbConfig"] as? String, pbAdSlot: args["pbAdSlot"] as? String) {
            adUnit.setImpORTBConfig(config)
        }
        if let config = args["globalOrtbConfig"] as? String { adUnit.setGlobalORTBConfig(config) }
        adUnit.delegate = self
        return adUnit
    }

    // MARK: - InterstitialAdUnitDelegate

    func interstitialDidReceiveAd(_ interstitial: InterstitialRenderingAdUnit) {
        send(interstitial, "onAdLoaded")
    }

    func interstitial(_ interstitial: InterstitialRenderingAdUnit, didFailToReceiveAdWithError error: Error?) {
        send(interstitial, "onAdFailed", error: PrebidErrorFormatter.describe(error))
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
