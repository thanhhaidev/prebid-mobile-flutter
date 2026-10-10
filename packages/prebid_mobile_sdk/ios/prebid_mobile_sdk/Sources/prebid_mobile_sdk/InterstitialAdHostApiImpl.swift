import Flutter
import PrebidMobile
import UIKit

/// InterstitialAdHostApi: rendering interstitials (Prebid renders).
final class InterstitialAdHostApiImpl: InterstitialAdHostApi {
    private let flutterApi: AdFlutterApi
    private var interstitialAds: [Int64: InterstitialRenderingAdUnit] = [:]

    init(flutterApi: AdFlutterApi) {
        self.flutterApi = flutterApi
    }

    func loadAd(adId: Int64, configId: String, adFormats: [String]?, videoConfig: VideoParametersConfig?, impOrtbConfig: String?, controls: FullscreenControlsConfig?) throws {
        let adUnit: InterstitialRenderingAdUnit
        if let minSize = controls?.minSizePercentage {
            adUnit = InterstitialRenderingAdUnit(configID: configId, minSizePercentage: minSize)
        } else {
            adUnit = InterstitialRenderingAdUnit(configID: configId)
        }
        if let impOrtbConfig = impOrtbConfig { adUnit.setImpORTBConfig(impOrtbConfig) }
        controls?.apply(to: adUnit)

        if let formats = adFormats {
            var adUnitFormats: Set<AdFormat> = []
            for f in formats {
                if f == "banner" { adUnitFormats.insert(.banner) }
                if f == "video" { adUnitFormats.insert(.video) }
            }
            if !adUnitFormats.isEmpty { adUnit.adFormats = adUnitFormats }
        }

        // videoParameters is get-only but returns the ad unit's live
        // (reference-type) parameters, so configure it in place.
        videoConfig?.apply(to: adUnit.videoParameters)

        let delegate = InterstitialDelegate(adId: adId, flutterApi: flutterApi)
        adUnit.delegate = delegate
        objc_setAssociatedObject(adUnit, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        interstitialAds[adId] = adUnit
        adUnit.loadAd()
    }

    func show(adId: Int64) throws {
        guard interstitialAds[adId]?.isReady == true else {
            return flutterApi.sendAdFailed(adId, PrebidPresenter.notReady)
        }
        PrebidPresenter.whenReady(fail: { [weak self] error in self?.flutterApi.sendAdFailed(adId, error) }) { [weak self] viewController in
            // Re-checked: a retry runs later, after a possible destroy.
            guard let self = self else { return }
            guard let interstitial = self.interstitialAds[adId], interstitial.isReady else {
                return self.flutterApi.sendAdFailed(adId, PrebidPresenter.notReady)
            }
            interstitial.show(from: viewController)
        }
    }

    func destroy(adId: Int64) throws {
        interstitialAds.removeValue(forKey: adId)
    }

    func destroyAll() -> [Int64] {
        let ids = Array(interstitialAds.keys)
        interstitialAds.removeAll()
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
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdFailed", error: PrebidErrorFormatter.describe(error))) { _ in }
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
