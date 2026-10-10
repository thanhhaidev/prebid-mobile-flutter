import Flutter
import PrebidMobile
import UIKit

/// InterstitialAdHostApi: rendering interstitials (Prebid renders).
final class InterstitialAdHostApiImpl: InterstitialAdHostApi {
    private let flutterApi: AdFlutterApi
    private var interstitialAds: [Int64: InterstitialRenderingAdUnit] = [:]
    // Prebid holds the delegate weakly; kept here until the ad is destroyed.
    private var delegates: [Int64: InterstitialDelegate] = [:]

    init(flutterApi: AdFlutterApi) {
        self.flutterApi = flutterApi
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
        let adUnit: InterstitialRenderingAdUnit
        if let minSize = controls?.minSizePercentage {
            adUnit = InterstitialRenderingAdUnit(configID: configId, minSizePercentage: minSize)
        } else {
            adUnit = InterstitialRenderingAdUnit(configID: configId)
        }
        // Prebid iOS has no pbAdSlot setter on rendering units: send it in the imp.
        if let config = impOrtb(impOrtbConfig, pbAdSlot: pbAdSlot) { adUnit.setImpORTBConfig(config) }
        if let globalOrtbConfig = globalOrtbConfig { adUnit.setGlobalORTBConfig(globalOrtbConfig) }
        controls?.apply(to: adUnit)
        if let formats = adFormatSet(adFormats) { adUnit.adFormats = formats }

        // videoParameters is get-only but returns the ad unit's live
        // (reference-type) parameters, so configure it in place.
        videoConfig?.apply(to: adUnit.videoParameters)

        let delegate = InterstitialDelegate(adId: adId, flutterApi: flutterApi)
        if let pos = adPosition.flatMap({ AdPosition(rawValue: Int($0)) }) { adUnit.adPosition = pos }
        adUnit.delegate = delegate
        delegates[adId] = delegate

        interstitialAds[adId] = adUnit
        adUnit.loadAd()
    }

    func show(adId: Int64) throws {
        guard interstitialAds[adId]?.isReady == true else {
            return flutterApi.sendAdFailed(adId, PrebidPresenter.notReady)
        }
        PrebidPresenter.whenReady(
            fail: { [weak self] error in self?.flutterApi.sendAdFailed(adId, error) },
            present: { [weak self] viewController in
                // Re-checked: a retry runs later, after a possible destroy.
                guard let self = self else { return }
                guard let interstitial = self.interstitialAds[adId], interstitial.isReady else {
                    return self.flutterApi.sendAdFailed(adId, PrebidPresenter.notReady)
                }
                interstitial.show(from: viewController)
            })
    }

    func destroy(adId: Int64) throws {
        // The unit may outlive this (e.g. while on screen): detach it so it
        // stops reporting under this ad id.
        interstitialAds.removeValue(forKey: adId)?.delegate = nil
        delegates.removeValue(forKey: adId)
    }

    func destroyAll() -> [Int64] {
        let ids = Array(interstitialAds.keys)
        for id in ids { try? destroy(adId: id) }
        return ids
    }
}

private final class InterstitialDelegate: NSObject, InterstitialAdUnitDelegate {
    let adId: Int64
    let flutterApi: AdFlutterApi

    init(adId: Int64, flutterApi: AdFlutterApi) {
        self.adId = adId
        self.flutterApi = flutterApi
    }

    func interstitialDidReceiveAd(_ interstitial: InterstitialRenderingAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdLoaded")) { _ in }
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
