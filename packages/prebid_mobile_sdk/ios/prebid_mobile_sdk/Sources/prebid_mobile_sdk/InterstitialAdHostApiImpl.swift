import Flutter
import PrebidMobile
import UIKit

/// InterstitialAdHostApi: rendering interstitials (Prebid renders).
final class InterstitialAdHostApiImpl: InterstitialAdHostApi {
    private let flutterApi: AdFlutterApi
    let store: FullscreenAdStore

    init(flutterApi: AdFlutterApi) {
        self.flutterApi = flutterApi
        store = FullscreenAdStore(flutterApi: flutterApi)
    }

    func loadAd(
        adId: Int64,
        configId: String,
        adFormats: [String]?,
        videoConfig: VideoParametersConfig?,
        impOrtbConfig: String?,
        globalOrtbConfig: String?,
        controls: FullscreenControlsConfig?,
        pbAdSlot: String?,
        adPosition: Int64?
    ) throws {
        // A reload replaces the previous unit, which must stop sending events
        // under this ad id.
        try destroy(adId: adId)
        let handler = BidKeepingInterstitialHandler()
        let adUnit: InterstitialRenderingAdUnit
        if let minSize = controls?.minSizePercentage {
            adUnit = InterstitialRenderingAdUnit(configID: configId, minSizePercentage: minSize, eventHandler: handler)
        } else {
            adUnit = InterstitialRenderingAdUnit(configID: configId, eventHandler: handler)
        }
        // Prebid iOS has no pbAdSlot setter on rendering units: send it in the imp.
        if let config = impOrtb(impOrtbConfig, pbAdSlot: pbAdSlot) { adUnit.setImpORTBConfig(config) }
        if let globalOrtbConfig = globalOrtbConfig { adUnit.setGlobalORTBConfig(globalOrtbConfig) }
        controls?.apply(to: adUnit)
        if let formats = adFormatSet(adFormats) { adUnit.adFormats = formats }

        // videoParameters is get-only but returns the ad unit's live
        // (reference-type) parameters, so configure it in place.
        videoConfig?.apply(to: adUnit.videoParameters)

        let delegate = InterstitialDelegate(adId: adId, flutterApi: flutterApi, handler: handler)
        if let pos = adPosition.flatMap({ AdPosition(rawValue: Int($0)) }) { adUnit.adPosition = pos }
        adUnit.delegate = delegate

        store.put(adId, adUnit, delegate: delegate)
        adUnit.loadAd()
    }

    func show(adId: Int64) throws {
        store.show(adId)
    }

    func destroy(adId: Int64) throws {
        store.remove(adId)
    }
}

private final class InterstitialDelegate: NSObject, InterstitialAdUnitDelegate {
    let adId: Int64
    let flutterApi: AdFlutterApi
    let handler: BidKeepingInterstitialHandler

    init(adId: Int64, flutterApi: AdFlutterApi, handler: BidKeepingInterstitialHandler) {
        self.adId = adId
        self.flutterApi = flutterApi
        self.handler = handler
    }

    func interstitialDidReceiveAd(_ interstitial: InterstitialRenderingAdUnit) {
        let event = AdEvent(adId: adId, eventName: "onAdLoaded", winningBid: handler.bidResponse?.winningBidData)
        flutterApi.onAdEvent(event: event) { _ in }
    }

    func interstitial(_ interstitial: InterstitialRenderingAdUnit, didFailToReceiveAdWithError error: Error?) {
        flutterApi.onAdEvent(
            event: AdEvent(adId: adId, eventName: "onAdFailed", error: PrebidErrorFormatter.describe(error))
        ) { _ in }
    }

    func interstitialWillPresentAd(_ interstitial: InterstitialRenderingAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdDisplayed")) { _ in }
    }

    func interstitialDidDismissAd(_ interstitial: InterstitialRenderingAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdClosed")) { _ in }
    }

    func interstitialDidClickAd(_ interstitial: InterstitialRenderingAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdClicked")) { _ in }
    }

    func interstitialDidExpireAd(_ interstitial: InterstitialRenderingAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdExpired")) { _ in }
    }
}
