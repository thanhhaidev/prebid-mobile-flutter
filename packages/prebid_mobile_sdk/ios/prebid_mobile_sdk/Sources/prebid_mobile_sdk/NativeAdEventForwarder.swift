import Flutter
import PrebidMobile
import UIKit

/// `NativeAdEventDelegate` → Flutter, one per ad (it outlives platform views).
///
/// Prebid iOS calls `adDidLogImpression` only after an `eventtrackers` URL
/// request succeeds: never when the response has no event trackers, and only
/// after a 300 s retry when the request fails. So the impression is reported
/// from the same IAB viewability rule Prebid applies before firing its
/// trackers (at least half the view on screen for 1 s, checked every 0.25 s),
/// with the delegate as a fallback.
final class NativeAdEventForwarder: NSObject, NativeAdEventDelegate {
    private let adId: Int64
    private let flutterApi: AdFlutterApi

    private static let checkInterval: TimeInterval = 0.25
    private static let requiredViewableChecks = 5 // 1 s / 0.25 s + 1, as Prebid
    private weak var watchedView: UIView?
    private var viewabilityTimer: Timer?
    private var viewableChecks = 0

    /// The fraction of the view Flutter paints on screen, reported by the
    /// Dart widget; 1 until the first report.
    var flutterVisibleFraction: Double = 1

    init(adId: Int64, flutterApi: AdFlutterApi) {
        self.adId = adId
        self.flutterApi = flutterApi
    }

    deinit {
        viewabilityTimer?.invalidate()
    }

    // Prebid calls this once per impression tracker URL; report one impression.
    private var impressionReported = false

    func watchViewability(of view: UIView) {
        guard !impressionReported else { return }
        watchedView = view
        viewableChecks = 0
        viewabilityTimer?.invalidate()
        viewabilityTimer = Timer.scheduledTimer(
            withTimeInterval: Self.checkInterval,
            repeats: true
        ) { [weak self] timer in
            guard let self = self, let view = self.watchedView else {
                timer.invalidate()
                return
            }
            let viewable = self.flutterVisibleFraction >= 0.5 && Self.isAtLeastHalfViewable(view)
            self.viewableChecks = viewable ? self.viewableChecks + 1 : 0
            if self.viewableChecks >= Self.requiredViewableChecks {
                self.reportImpression()
            }
        }
    }

    func stopWatching() {
        viewabilityTimer?.invalidate()
        viewabilityTimer = nil
    }

    private func reportImpression() {
        stopWatching()
        guard !impressionReported else { return }
        impressionReported = true
        send("onAdImpression")
    }

    /// Prebid's `UIView.pb_isAtLeastHalfViewable` (internal to the SDK),
    /// stricter: a transparent view or ancestor isn't viewable, and the
    /// visible area is clipped to the window and to every ancestor that
    /// clips its subviews. Flutter applies its clips (scroll viewports under
    /// an app bar, ClipRect/ClipRRect) to platform views as layer masks,
    /// which expose no geometry to read: those come from the Dart widget as
    /// `flutterVisibleFraction`.
    private static func isAtLeastHalfViewable(_ view: UIView) -> Bool {
        guard let window = view.window else { return false }
        let rect = view.convert(view.bounds, to: nil)
        guard rect.width * rect.height > 0 else { return false }
        var visible = rect.intersection(window.bounds)
        var current: UIView? = view
        while let v = current {
            if v.isHidden || v.alpha < 0.01 { return false }
            if v !== view, v.clipsToBounds {
                visible = visible.intersection(v.convert(v.bounds, to: nil))
            }
            current = v.superview
        }
        guard !visible.isNull else { return false }
        return visible.width * visible.height >= 0.5 * rect.width * rect.height
    }

    func adDidLogImpression(ad: NativeAd) {
        DispatchQueue.main.async { [weak self] in
            self?.reportImpression()
        }
    }

    func adWasClicked(ad: NativeAd) {
        send("onAdClicked")
    }

    func adDidExpire(ad: NativeAd) {
        DispatchQueue.main.async { [weak self] in self?.reportExpired() }
    }

    private var expiredReported = false

    /// Prebid stops tracking an expired ad; so does the watcher. Reported
    /// once, whether Prebid's expiry or a refused `registerView` comes first.
    func reportExpired() {
        stopWatching()
        guard !expiredReported else { return }
        expiredReported = true
        send("onAdExpired")
    }

    private func send(_ name: String) {
        DispatchQueue.main.async { [adId, flutterApi] in
            flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: name)) { _ in }
        }
    }
}
