import Flutter
import UIKit
import GoogleMobileAds
import PrebidMobile
import PrebidMobileAdMobAdapters

/// One AdMob-mediated interstitial: the Prebid ad unit that runs the auction
/// and, once loaded, the AdMob ad.
final class AdMobInterstitial: FullscreenAd {
    let adUnit: MediationInterstitialAdUnit
    let request: GoogleMobileAds.Request
    let adMobAdUnitId: String
    let dropBidProbability: Double
    // Retained for the ad's lifetime: the auction runs through it.
    private let mediationDelegate: AdMobMediationInterstitialUtils
    var interstitial: GoogleMobileAds.InterstitialAd?
    var events: FullScreenEvents?

    init(args: [String: Any]) {
        let request = GoogleMobileAds.Request()
        let mediationDelegate = AdMobMediationInterstitialUtils(gadRequest: request)
        let controls = FullscreenControls(args["controls"])
        let adUnit = MediationInterstitialAdUnit(
            configId: args["configId"] as? String ?? "",
            minSizePercentage: controls?.minSizePercentage,
            mediationDelegate: mediationDelegate
        )
        controls?.apply(to: adUnit)
        applyVideoParameters(args["videoParameters"], to: adUnit.videoParameters)
        // Prebid iOS has no pbAdSlot setter on this ad unit: send it in the imp.
        if let config = impOrtb(args["impOrtbConfig"] as? String, pbAdSlot: args["pbAdSlot"] as? String) {
            adUnit.setImpORTBConfig(config)
        }
        if let config = args["globalOrtbConfig"] as? String { adUnit.setGlobalORTBConfig(config) }
        adUnit.adFormats = adFormatsFrom(args["adFormats"], isVideo: args["isVideo"] as? Bool ?? false)
        self.request = request
        self.mediationDelegate = mediationDelegate
        self.adUnit = adUnit
        adMobAdUnitId = args["adMobAdUnitId"] as? String ?? ""
        dropBidProbability = debugDropBidProbability(args["debugDropBidProbability"])
    }

    var isLoaded: Bool { interstitial != nil }

    func destroy() {
        interstitial?.fullScreenContentDelegate = nil
        interstitial = nil
        events = nil
    }
}

/// AdMob-mediated interstitials over the `prebid_mobile_sdk_admob/interstitial`
/// method channel: Prebid's `MediationInterstitialAdUnit` runs the auction and
/// the winning bid reaches AdMob's `InterstitialAd` through the Prebid adapter.
final class AdMobInterstitialManager: FullscreenAdManager<AdMobInterstitial> {

    init(messenger: FlutterBinaryMessenger) {
        super.init(name: "prebid_mobile_sdk_admob/interstitial", messenger: messenger)
    }

    override func makeAd(adId: Int, args: [String: Any]) -> AdMobInterstitial {
        AdMobInterstitial(args: args)
    }

    override func load(_ ad: AdMobInterstitial, adId: Int) {
        ad.adUnit.fetchDemand { [weak self, weak ad] _ in
            onMain {
                // Destroyed / replaced while the auction ran: skip the load.
                guard let self = self, let ad = ad, self.isCurrent(ad, adId: adId) else { return }
                maybeDropBid(ad.dropBidProbability, from: ad.request)
                GoogleMobileAds.InterstitialAd.load(
                    with: ad.adMobAdUnitId,
                    request: ad.request
                ) { [weak self, weak ad] interstitial, error in
                    guard let self = self, let ad = ad, self.isCurrent(ad, adId: adId) else { return }
                    guard let interstitial = interstitial else {
                        return self.send(adId, "onAdFailed", error: PrebidErrorFormatter.describe(error))
                    }
                    let events = FullScreenEvents { [weak self, weak ad] event, error in
                        guard let self = self, let ad = ad, self.isCurrent(ad, adId: adId) else { return }
                        self.send(adId, event, error: error.map { PrebidErrorFormatter.describe($0) })
                    }
                    ad.events = events
                    interstitial.fullScreenContentDelegate = events
                    ad.interstitial = interstitial
                    self.send(adId, "onAdLoaded")
                }
            }
        }
    }

    override func present(_ ad: AdMobInterstitial, adId: Int, from controller: UIViewController) {
        ad.interstitial?.present(from: controller)
    }
}
