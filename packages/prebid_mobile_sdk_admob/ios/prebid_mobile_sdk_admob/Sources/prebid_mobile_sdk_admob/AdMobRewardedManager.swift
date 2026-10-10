import Flutter
import UIKit
import GoogleMobileAds
import PrebidMobile
import PrebidMobileAdMobAdapters

/// One AdMob-mediated rewarded ad: the Prebid ad unit that runs the auction
/// and, once loaded, the AdMob ad.
final class AdMobRewarded: FullscreenAd {
    let adUnit: MediationRewardedAdUnit
    let request: GoogleMobileAds.Request
    let adMobAdUnitId: String
    let dropBidProbability: Double
    // Retained for the ad's lifetime: the auction runs through it.
    private let mediationDelegate: AdMobMediationRewardedUtils
    var rewarded: GoogleMobileAds.RewardedAd?
    var events: FullScreenEvents?

    init(args: [String: Any]) {
        let request = GoogleMobileAds.Request()
        let mediationDelegate = AdMobMediationRewardedUtils(gadRequest: request)
        let adUnit = MediationRewardedAdUnit(
            configId: args["configId"] as? String ?? "",
            mediationDelegate: mediationDelegate
        )
        FullscreenControls(args["controls"])?.apply(to: adUnit)
        applyVideoParameters(args["videoParameters"], to: adUnit.videoParameters)
        if let config = args["impOrtbConfig"] as? String { adUnit.setImpORTBConfig(config) }
        self.request = request
        self.mediationDelegate = mediationDelegate
        self.adUnit = adUnit
        adMobAdUnitId = args["adMobAdUnitId"] as? String ?? ""
        dropBidProbability = debugDropBidProbability(args["debugDropBidProbability"])
    }

    var isLoaded: Bool { rewarded != nil }

    func destroy() {
        rewarded?.fullScreenContentDelegate = nil
        rewarded = nil
        events = nil
    }
}

/// AdMob-mediated rewarded ads over the `prebid_mobile_sdk_admob/rewarded`
/// method channel: Prebid's `MediationRewardedAdUnit` runs the auction and the
/// winning bid reaches AdMob's `RewardedAd` through the Prebid adapter. The
/// reward is sent as `onUserEarnedReward`.
final class AdMobRewardedManager: FullscreenAdManager<AdMobRewarded> {

    init(messenger: FlutterBinaryMessenger) {
        super.init(name: "prebid_mobile_sdk_admob/rewarded", messenger: messenger)
    }

    override func makeAd(adId: Int, args: [String: Any]) -> AdMobRewarded {
        AdMobRewarded(args: args)
    }

    override func load(_ ad: AdMobRewarded, adId: Int) {
        ad.adUnit.fetchDemand { [weak self, weak ad] _ in
            onMain {
                // Destroyed / replaced while the auction ran: skip the load.
                guard let self = self, let ad = ad, self.isCurrent(ad, adId: adId) else { return }
                maybeDropBid(ad.dropBidProbability, from: ad.request)
                GoogleMobileAds.RewardedAd.load(
                    with: ad.adMobAdUnitId,
                    request: ad.request
                ) { [weak self, weak ad] rewarded, error in
                    guard let self = self, let ad = ad, self.isCurrent(ad, adId: adId) else { return }
                    guard let rewarded = rewarded else {
                        return self.send(adId, "onAdFailed", error: PrebidErrorFormatter.describe(error))
                    }
                    let events = FullScreenEvents { [weak self, weak ad] event, error in
                        guard let self = self, let ad = ad, self.isCurrent(ad, adId: adId) else { return }
                        self.send(adId, event, error: error.map { PrebidErrorFormatter.describe($0) })
                    }
                    ad.events = events
                    rewarded.fullScreenContentDelegate = events
                    ad.rewarded = rewarded
                    self.send(adId, "onAdLoaded")
                }
            }
        }
    }

    override func present(_ ad: AdMobRewarded, adId: Int, from controller: UIViewController) {
        guard let rewarded = ad.rewarded else { return }
        rewarded.present(from: controller) { [weak self, weak ad, weak rewarded] in
            guard let self = self, let ad = ad, self.isCurrent(ad, adId: adId),
                  let reward = rewarded?.adReward else { return }
            // Same reward keys as the GAM / MAX packages.
            self.send(
                adId,
                "onUserEarnedReward",
                extra: ["rewardType": reward.type, "rewardCount": reward.amount.intValue]
            )
        }
    }
}
