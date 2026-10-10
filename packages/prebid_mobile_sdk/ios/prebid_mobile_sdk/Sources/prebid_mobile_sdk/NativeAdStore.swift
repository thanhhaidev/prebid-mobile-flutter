import PrebidMobile
import UIKit

/// Loaded In-App native ads of one Flutter engine, keyed by the Dart ad id,
/// so a `NativeAdPlatformView` can render and register the ad for tracking.
/// One store per engine: every engine numbers its ads from the same start.
final class NativeAdStore {
    private(set) var ads: [Int64: NativeAd] = [:]

    /// The rendered, registered view of each ad. `NativeAd.registerView` only
    /// accepts one view per ad, so a platform view re-created for the same ad
    /// (e.g. after scrolling out of a list and back) reuses this one.
    var views: [Int64: UIView] = [:]

    /// Event delegates, held strongly: Prebid holds the ad's delegate weakly.
    private(set) var delegates: [Int64: NativeAdEventForwarder] = [:]

    /// Platform views currently showing each ad id, newest last.
    private var platformViews: [Int64: [Weak<NativeAdPlatformView>]] = [:]

    /// Stores a newly loaded ad. Its delegate is set now, not when it is
    /// rendered, so an ad that expires before it is shown still reports
    /// `onAdExpired`. The newest platform view already on screen for the id
    /// shows it (a reload keeps the same Dart widget).
    func put(_ adId: Int64, ad: NativeAd, delegate: NativeAdEventForwarder) {
        ads[adId] = ad
        delegates[adId] = delegate
        ad.delegate = delegate
        platformViews[adId]?.compactMap(\.value).last?.show()
    }

    func remove(_ adId: Int64) {
        ads.removeValue(forKey: adId)
        delegates.removeValue(forKey: adId)?.stopWatching()
        views.removeValue(forKey: adId)?.removeFromSuperview()
    }

    func removeAll() {
        Set(ads.keys).union(views.keys).union(delegates.keys).forEach(remove)
        platformViews.removeAll()
    }

    /// Clicks the ad as a tap on its registered view would (the custom-layout
    /// tracking view); false when that view isn't on screen. Prebid iOS has
    /// no public click API: its tap handler is an Objective-C method.
    func performClick(_ adId: Int64) -> Bool {
        let handleClick = NSSelectorFromString("handleClick")
        guard let ad = ads[adId], views[adId]?.window != nil, ad.responds(to: handleClick) else {
            return false
        }
        ad.perform(handleClick)
        return true
    }

    func attach(_ view: NativeAdPlatformView) {
        platformViews[view.adId, default: []].append(Weak(view))
    }

    func detach(_ view: NativeAdPlatformView) {
        platformViews[view.adId]?.removeAll { $0.value == nil || $0.value === view }
        if platformViews[view.adId]?.isEmpty == true { platformViews.removeValue(forKey: view.adId) }
    }
}

final class Weak<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}
