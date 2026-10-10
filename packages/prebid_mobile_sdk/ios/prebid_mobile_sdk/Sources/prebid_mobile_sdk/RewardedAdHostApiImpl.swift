import Flutter
import PrebidMobile
import UIKit

/// RewardedAdHostApi: rendering rewarded ads (Prebid renders).
final class RewardedAdHostApiImpl: RewardedAdHostApi {
    private let flutterApi: AdFlutterApi
    private var rewardedAds: [Int64: RewardedAdUnit] = [:]

    init(flutterApi: AdFlutterApi) {
        self.flutterApi = flutterApi
    }

    func loadAd(adId: Int64, configId: String, impOrtbConfig: String?, controls: FullscreenControlsConfig?) throws {
        let adUnit = RewardedAdUnit(configID: configId)
        if let impOrtbConfig = impOrtbConfig { adUnit.setImpORTBConfig(impOrtbConfig) }
        controls?.apply(to: adUnit)
        let delegate = RewardedDelegate(adId: adId, flutterApi: flutterApi)
        adUnit.delegate = delegate
        objc_setAssociatedObject(adUnit, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        rewardedAds[adId] = adUnit
        adUnit.loadAd()
    }

    func show(adId: Int64) throws {
        guard rewardedAds[adId]?.isReady == true else {
            return flutterApi.sendAdFailed(adId, PrebidPresenter.notReady)
        }
        PrebidPresenter.whenReady(fail: { [weak self] error in self?.flutterApi.sendAdFailed(adId, error) }) { [weak self] viewController in
            // Re-checked: a retry runs later, after a possible destroy.
            guard let self = self else { return }
            guard let rewarded = self.rewardedAds[adId], rewarded.isReady else {
                return self.flutterApi.sendAdFailed(adId, PrebidPresenter.notReady)
            }
            rewarded.show(from: viewController)
        }
    }

    func destroy(adId: Int64) throws {
        rewardedAds.removeValue(forKey: adId)
    }

    func destroyAll() -> [Int64] {
        let ids = Array(rewardedAds.keys)
        rewardedAds.removeAll()
        return ids
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
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdFailed", error: PrebidErrorFormatter.describe(error))) { _ in }
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
        flutterApi.onAdEvent(event: AdEvent(
            adId: adId,
            eventName: "onUserEarnedReward",
            reward: RewardData(
                type: reward.type ?? "reward",
                count: reward.count?.int64Value ?? 1,
                ext: reward.ext?.reduce(into: [String?: Any?]()) { $0[$1.key] = $1.value }
            )
        )) { _ in }
    }
}
