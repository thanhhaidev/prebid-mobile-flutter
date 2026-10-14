import Flutter
import PrebidMobile
import UIKit

/// A Prebid rendering fullscreen unit (interstitial or rewarded).
protocol FullscreenRenderingAdUnit: AnyObject {
    var isReady: Bool { get }
    func show(from controller: UIViewController)
    /// Stops the unit reporting to its delegate.
    func detachDelegate()
}

extension InterstitialRenderingAdUnit: FullscreenRenderingAdUnit {
    func detachDelegate() { delegate = nil }
}

extension RewardedAdUnit: FullscreenRenderingAdUnit {
    func detachDelegate() { delegate = nil }
}

/// Prebid's standalone interstitial event handler (Prebid always wins), which
/// also keeps the bid response: Prebid iOS keeps the unit's own internal, so
/// this is how `onAdLoaded` gets the winning bid.
final class BidKeepingInterstitialHandler: NSObject, InterstitialEventHandlerProtocol {
    weak var loadingDelegate: InterstitialEventLoadingDelegate?
    weak var interactionDelegate: InterstitialEventInteractionDelegate?
    private(set) var bidResponse: BidResponse?

    // Never shown: Prebid renders the ad itself once it wins.
    var isReady: Bool { false }
    func show(from viewController: UIViewController?) {}

    func requestAd(with bidResponse: BidResponse?) {
        self.bidResponse = bidResponse
        loadingDelegate?.prebidDidWin()
    }
}

/// [BidKeepingInterstitialHandler] for rewarded ads.
final class BidKeepingRewardedHandler: NSObject, RewardedEventHandlerProtocol {
    weak var loadingDelegate: InterstitialEventLoadingDelegate?
    weak var interactionDelegate: RewardedEventInteractionDelegate?
    private(set) var bidResponse: BidResponse?

    var isReady: Bool { false }
    func show(from viewController: UIViewController?) {}

    func requestAd(with bidResponse: BidResponse?) {
        self.bidResponse = bidResponse
        loadingDelegate?.prebidDidWin()
    }
}

/// The interstitial or rewarded units of one engine by ad id, with their
/// delegates (Prebid holds a delegate weakly), and how they're shown.
final class FullscreenAdStore {
    private let flutterApi: AdFlutterApi
    /// The engine's window, to present ads in (set from the registrar); the
    /// foreground key window when it returns nil.
    var engineWindow: () -> UIWindow? = { nil }
    private var units: [Int64: (unit: FullscreenRenderingAdUnit, delegate: AnyObject)] = [:]

    init(flutterApi: AdFlutterApi) {
        self.flutterApi = flutterApi
    }

    /// Keeps [unit] and its [delegate] as [adId]'s; [remove] the previous
    /// one first.
    func put(_ adId: Int64, _ unit: FullscreenRenderingAdUnit, delegate: AnyObject) {
        units[adId] = (unit, delegate)
    }

    func show(_ adId: Int64) {
        guard units[adId]?.unit.isReady == true else {
            return flutterApi.sendAdFailed(adId, PrebidPresenter.notReady)
        }
        PrebidPresenter.whenReady(
            in: engineWindow(),
            fail: { [weak self] error in self?.flutterApi.sendAdFailed(adId, error) },
            present: { [weak self] viewController in
                // Re-checked: a retry runs later, after a possible destroy.
                guard let self = self else { return }
                guard let unit = self.units[adId]?.unit, unit.isReady else {
                    return self.flutterApi.sendAdFailed(adId, PrebidPresenter.notReady)
                }
                unit.show(from: viewController)
            })
    }

    /// Drops [adId]'s unit. It may outlive this (e.g. while on screen):
    /// detached, it stops reporting under this ad id.
    func remove(_ adId: Int64) {
        units.removeValue(forKey: adId)?.unit.detachDelegate()
    }

    func removeAll() {
        for id in Array(units.keys) { remove(id) }
    }
}
