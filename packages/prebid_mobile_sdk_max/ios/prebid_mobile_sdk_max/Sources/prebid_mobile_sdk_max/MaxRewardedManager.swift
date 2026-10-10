import AppLovinSDK
import Flutter
import PrebidMobile
import PrebidMobileMAXAdapters
import UIKit

/// One rewarded ad: the Prebid ad unit, the shared MAX ad it bids into, and
/// what keeps the auction and the MAX delegates alive.
final class MaxRewardedEntry {
    let adUnit: MediationRewardedAdUnit
    let mediationDelegate: MAXMediationRewardedUtils
    let rewarded: MARewardedAd
    let proxy: MaxAdEventProxy
    let dropBidProbability: Double

    init(
        adUnit: MediationRewardedAdUnit,
        mediationDelegate: MAXMediationRewardedUtils,
        rewarded: MARewardedAd,
        proxy: MaxAdEventProxy,
        dropBidProbability: Double
    ) {
        self.adUnit = adUnit
        self.mediationDelegate = mediationDelegate
        self.rewarded = rewarded
        self.proxy = proxy
        self.dropBidProbability = dropBidProbability
    }
}

/// MAX-mediated rewarded ads over the `prebid_mobile_sdk_max/rewarded` method
/// channel.
///
/// MAX hands out one shared `MARewardedAd` per ad unit, so at most one `adId`
/// owns a unit at a time: a new load on the same unit takes it over (the
/// previous owner gets `onAdFailed`), and only the owner's events are routed.
/// While the owner's ad is on screen the unit cannot be handed over (its
/// reward and close would reach the new owner), so a load on it fails.
final class MaxRewardedManager: FullscreenAdManager<MaxRewardedEntry> {

    /// MAX ad unit identifier → the `adId` that currently owns its shared ad.
    private var ownerByUnit: [String: Int] = [:]
    /// MAX ad units whose ad is on screen (from displayed until hidden or
    /// display-failed).
    private var showingUnits: Set<String> = []

    private static let showingError =
        "Another ad for this MAX ad unit is showing; load the next one after onAdClosed"

    init(messenger: FlutterBinaryMessenger) {
        super.init(name: "prebid_mobile_sdk_max/rewarded", messenger: messenger)
    }

    // Handing the shared instance over now would route the showing ad's
    // reward and close to this ad; leave it alone.
    override func refuseLoad(_ adId: Int, _ args: [String: Any]) -> String? {
        showingUnits.contains(Self.maxAdUnitId(args)) ? Self.showingError : nil
    }

    override func create(_ adId: Int, _ args: [String: Any]) -> MaxRewardedEntry {
        let configId = args["configId"] as? String ?? ""
        let maxAdUnitId = Self.maxAdUnitId(args)

        // The shared instance moves to this adId; the previous owner stops
        // receiving events and is told why.
        if let previous = ownerByUnit[maxAdUnitId], previous != adId {
            release(previous)
            send(previous, "onAdFailed", error: "Replaced by another ad on the same MAX ad unit")
        }

        let rewarded = MARewardedAd.shared(withAdUnitIdentifier: maxAdUnitId)
        let mediationDelegate = MAXMediationRewardedUtils(rewardedAd: rewarded)
        let adUnit = MediationRewardedAdUnit(configId: configId, mediationDelegate: mediationDelegate)
        FullscreenControls(args["controls"])?.apply(to: adUnit)
        applyVideoParameters(args["videoParameters"], to: adUnit.videoParameters)
        // Prebid iOS has no pbAdSlot setter on this ad unit: send it in the imp.
        if let config = impOrtb(args["impOrtbConfig"] as? String, pbAdSlot: args["pbAdSlot"] as? String) {
            adUnit.setImpORTBConfig(config)
        }
        if let config = args["globalOrtbConfig"] as? String { adUnit.setGlobalORTBConfig(config) }

        let proxy = MaxAdEventProxy { [weak self] event, payload in
            guard let self = self else { return }
            switch event {
            case "onAdDisplayed":
                self.showingUnits.insert(maxAdUnitId)
            case "onAdClosed", "onAdFailed":
                // Hidden, or failed to display (a load cannot fail while the
                // unit shows: loads are refused meanwhile).
                self.showingUnits.remove(maxAdUnitId)
            default:
                break
            }
            self.send(adId, event, extras: payload)
        }
        rewarded.delegate = proxy
        rewarded.revenueDelegate = proxy
        ownerByUnit[maxAdUnitId] = adId
        return MaxRewardedEntry(
            adUnit: adUnit,
            mediationDelegate: mediationDelegate,
            rewarded: rewarded,
            proxy: proxy,
            dropBidProbability: debugDropBidProbability(args["debugDropBidProbability"])
        )
    }

    override func load(_ adId: Int, _ ad: MaxRewardedEntry) {
        ad.adUnit.fetchDemand { [weak self, weak ad] _ in
            // Destroyed / replaced while the auction ran: skip the load.
            guard let self = self, let ad = ad, self.isCurrent(adId, ad) else { return }
            if shouldDropBid(ad.dropBidProbability) {
                ad.rewarded.setLocalExtraParameterForKey(PBMMediationAdUnitBidKey, value: nil)
            }
            ad.rewarded.load()
        }
    }

    override func isLoaded(_ ad: MaxRewardedEntry) -> Bool {
        ad.rewarded.isReady
    }

    override func show(_ adId: Int, _ ad: MaxRewardedEntry, from viewController: UIViewController) {
        ad.rewarded.show(forPlacement: nil, customData: nil, viewController: viewController)
    }

    /// The shared MAX ad is only detached when `adId` still owns its unit: a
    /// replaced ad must not touch the instance (and delegates) the new owner
    /// is using.
    override func destroy(_ adId: Int, _ ad: MaxRewardedEntry) {
        let unitId = ad.rewarded.adUnitIdentifier
        guard ownerByUnit[unitId] == adId else { return }
        ownerByUnit.removeValue(forKey: unitId)
        showingUnits.remove(unitId)
        ad.rewarded.delegate = nil
        ad.rewarded.revenueDelegate = nil
    }

    private static func maxAdUnitId(_ args: [String: Any]) -> String {
        args["maxAdUnitId"] as? String ?? ""
    }
}
