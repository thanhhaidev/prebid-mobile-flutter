import Flutter
import UIKit
import PrebidMobile
import PrebidMobileMAXAdapters
import AppLovinSDK

/// One interstitial: the Prebid ad unit, the MAX ad it bids into, and what
/// keeps the auction and the MAX delegates alive.
final class MaxInterstitialEntry {
    let adUnit: MediationInterstitialAdUnit
    let mediationDelegate: MAXMediationInterstitialUtils
    let interstitial: MAInterstitialAd
    let proxy: MaxAdEventProxy
    let dropBidProbability: Double

    init(
        adUnit: MediationInterstitialAdUnit,
        mediationDelegate: MAXMediationInterstitialUtils,
        interstitial: MAInterstitialAd,
        proxy: MaxAdEventProxy,
        dropBidProbability: Double
    ) {
        self.adUnit = adUnit
        self.mediationDelegate = mediationDelegate
        self.interstitial = interstitial
        self.proxy = proxy
        self.dropBidProbability = dropBidProbability
    }
}

/// MAX-mediated interstitials over the `prebid_mobile_sdk_max/interstitial`
/// method channel.
final class MaxInterstitialManager: FullscreenAdManager<MaxInterstitialEntry> {

    init(messenger: FlutterBinaryMessenger) {
        super.init(name: "prebid_mobile_sdk_max/interstitial", messenger: messenger)
    }

    override func create(_ adId: Int, _ args: [String: Any]) -> MaxInterstitialEntry {
        let configId = args["configId"] as? String ?? ""
        let maxAdUnitId = args["maxAdUnitId"] as? String ?? ""
        let isVideo = args["isVideo"] as? Bool ?? false

        let interstitial = MAInterstitialAd(adUnitIdentifier: maxAdUnitId)
        let mediationDelegate = MAXMediationInterstitialUtils(interstitialAd: interstitial)
        let controls = FullscreenControls(args["controls"])
        let adUnit = MediationInterstitialAdUnit(
            configId: configId,
            minSizePercentage: controls?.minSizePercentage,
            mediationDelegate: mediationDelegate
        )
        adUnit.adFormats = adFormatsFrom(args["adFormats"], isVideo: isVideo)
        controls?.apply(to: adUnit)
        applyVideoParameters(args["videoParameters"], to: adUnit.videoParameters)
        // Prebid iOS has no pbAdSlot setter on this ad unit: send it in the imp.
        if let config = impOrtb(args["impOrtbConfig"] as? String, pbAdSlot: args["pbAdSlot"] as? String) {
            adUnit.setImpORTBConfig(config)
        }
        if let config = args["globalOrtbConfig"] as? String { adUnit.setGlobalORTBConfig(config) }

        let proxy = MaxAdEventProxy { [weak self] event, payload in
            self?.send(adId, event, extras: payload)
        }
        interstitial.delegate = proxy
        interstitial.revenueDelegate = proxy
        return MaxInterstitialEntry(
            adUnit: adUnit,
            mediationDelegate: mediationDelegate,
            interstitial: interstitial,
            proxy: proxy,
            dropBidProbability: debugDropBidProbability(args["debugDropBidProbability"])
        )
    }

    override func load(_ adId: Int, _ ad: MaxInterstitialEntry) {
        ad.adUnit.fetchDemand { [weak self, weak ad] _ in
            // Destroyed / replaced while the auction ran: skip the load.
            guard let self = self, let ad = ad, self.isCurrent(adId, ad) else { return }
            if shouldDropBid(ad.dropBidProbability) {
                ad.interstitial.setLocalExtraParameterForKey(PBMMediationAdUnitBidKey, value: nil)
            }
            ad.interstitial.load()
        }
    }

    override func isLoaded(_ ad: MaxInterstitialEntry) -> Bool {
        ad.interstitial.isReady
    }

    override func show(_ adId: Int, _ ad: MaxInterstitialEntry, from viewController: UIViewController) {
        ad.interstitial.show(forPlacement: nil, customData: nil, viewController: viewController)
    }

    /// Detaching the (weak) MAX delegates stops late callbacks.
    override func destroy(_ adId: Int, _ ad: MaxInterstitialEntry) {
        ad.interstitial.delegate = nil
        ad.interstitial.revenueDelegate = nil
    }
}
