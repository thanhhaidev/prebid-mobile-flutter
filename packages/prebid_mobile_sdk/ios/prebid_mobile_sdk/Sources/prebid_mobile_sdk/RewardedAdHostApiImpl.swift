import Flutter
import PrebidMobile
import UIKit

/// RewardedAdHostApi: rendering rewarded ads (Prebid renders).
final class RewardedAdHostApiImpl: RewardedAdHostApi {
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
        try destroy(adId: adId)
        let adUnit: RewardedAdUnit
        if let minSize = controls?.minSizePercentage {
            adUnit = RewardedAdUnit(configID: configId, minSizePercentage: minSize)
        } else {
            adUnit = RewardedAdUnit(configID: configId)
        }
        // Prebid iOS has no pbAdSlot setter on rendering units: send it in the imp.
        if let config = impOrtb(impOrtbConfig, pbAdSlot: pbAdSlot) { adUnit.setImpORTBConfig(config) }
        if let globalOrtbConfig = globalOrtbConfig { adUnit.setGlobalORTBConfig(globalOrtbConfig) }
        if let formats = adFormatSet(adFormats) { adUnit.adFormats = formats }
        // videoParameters is get-only but returns the ad unit's live
        // (reference-type) parameters, so configure it in place.
        videoConfig?.apply(to: adUnit.videoParameters)
        controls?.apply(to: adUnit)
        let delegate = RewardedDelegate(adId: adId, flutterApi: flutterApi)
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

private final class RewardedDelegate: NSObject, RewardedAdUnitDelegate {
    let adId: Int64
    let flutterApi: AdFlutterApi

    init(adId: Int64, flutterApi: AdFlutterApi) {
        self.adId = adId
        self.flutterApi = flutterApi
    }

    func rewardedAdDidReceiveAd(_ rewardedAd: RewardedAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdLoaded")) { _ in }
    }

    func rewardedAd(_ rewardedAd: RewardedAdUnit, didFailToReceiveAdWithError error: Error?) {
        flutterApi.onAdEvent(
            event: AdEvent(adId: adId, eventName: "onAdFailed", error: PrebidErrorFormatter.describe(error))
        ) { _ in }
    }

    func rewardedAdWillPresentAd(_ rewardedAd: RewardedAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdDisplayed")) { _ in }
    }

    func rewardedAdDidDismissAd(_ rewardedAd: RewardedAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdClosed")) { _ in }
    }

    func rewardedAdDidClickAd(_ rewardedAd: RewardedAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdClicked")) { _ in }
    }

    func rewardedAdDidExpire(_ rewardedAd: RewardedAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdExpired")) { _ in }
    }

    func rewardedAdUserDidEarnReward(_ rewardedAd: RewardedAdUnit, reward: PrebidReward) {
        flutterApi.onAdEvent(
            event: AdEvent(
                adId: adId,
                eventName: "onUserEarnedReward",
                reward: RewardData(
                    type: reward.type ?? "reward",
                    count: reward.count?.int64Value ?? 1,
                    ext: reward.ext?.reduce(into: [String?: Any?]()) { $0[$1.key] = $1.value }
                )
            )
        ) { _ in }
    }
}
