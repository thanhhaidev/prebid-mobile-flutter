import Flutter
import UIKit
import PrebidMobile

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

/// Re-measures the native content whenever its width changes: Flutter sizes
/// the platform view after it is created, and again on rotation.
private final class NativeAdContainer: UIView {
    var onWidthChange: ((CGFloat) -> Void)?
    private var lastWidth: CGFloat = 0

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.width != lastWidth else { return }
        lastWidth = bounds.width
        onWidthChange?(bounds.width)
    }
}

/// PlatformView factory for `PrebidNativeAdView`: renders a loaded `NativeAd`
/// natively and calls `registerView` so Prebid tracks viewability-based
/// impressions and clicks.
final class NativeAdViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger
    private let store: NativeAdStore

    init(messenger: FlutterBinaryMessenger, store: NativeAdStore) {
        self.messenger = messenger
        self.store = store
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return NativeAdPlatformView(
            viewId: viewId,
            messenger: messenger,
            store: store,
            args: args as? [String: Any] ?? [:]
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

final class NativeAdPlatformView: NSObject, FlutterPlatformView {

    private let container = NativeAdContainer()
    let adId: Int64
    private let methodChannel: FlutterMethodChannel
    private let store: NativeAdStore
    private var lastReportedHeight: CGFloat = 0

    init(viewId: Int64, messenger: FlutterBinaryMessenger, store: NativeAdStore, args: [String: Any]) {
        adId = (args["adId"] as? NSNumber)?.int64Value ?? 0
        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_sdk/native_ad_\(viewId)",
            binaryMessenger: messenger
        )
        self.store = store
        super.init()
        container.onWidthChange = { [weak self] width in self?.reportHeight(width: width) }
        // The fraction of the view Flutter paints on screen, from
        // PrebidNativeAdView: Flutter's clips (scroll viewports, ClipRect)
        // reach the platform view as a mask the native check can't read.
        methodChannel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "setVisibleFraction" else {
                result(FlutterMethodNotImplemented)
                return
            }
            if let self = self, let fraction = (call.arguments as? NSNumber)?.doubleValue {
                self.store.delegates[self.adId]?.flutterVisibleFraction = fraction
            }
            result(nil)
        }
        store.attach(self)
        show()
    }

    deinit {
        methodChannel.setMethodCallHandler(nil)
        store.detach(self)
        // Keep the registered view for a re-created platform view;
        // NativeAdStore.remove releases it.
        // A newer platform view may already have taken it.
        if let content = store.views[adId], content.superview === container {
            content.removeFromSuperview()
        }
    }

    /// Shows the ad's registered view, or renders and registers the ad the
    /// first time; also called by the store when the ad is reloaded.
    func show() {
        container.subviews.forEach { $0.removeFromSuperview() }
        if let content = store.views[adId] {
            content.removeFromSuperview()
            embed(content)
            reportHeight()
        } else if let ad = store.ads[adId], let forwarder = store.delegates[adId] {
            render(ad, forwarder: forwarder)
        }
    }

    private func embed(_ content: UIView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
    }

    func view() -> UIView {
        return container
    }

    // MARK: - Rendering

    private func render(_ ad: NativeAd, forwarder: NativeAdEventForwarder) {
        let iconView = UIImageView()
        let mainImageView = UIImageView()
        let titleLabel = UILabel()
        let sponsoredLabel = UILabel()
        let bodyLabel = UILabel()
        let ctaButton = UIButton(type: .system)

        titleLabel.font = .boldSystemFont(ofSize: 15)
        titleLabel.numberOfLines = 2
        titleLabel.text = ad.title
        sponsoredLabel.font = .systemFont(ofSize: 11)
        sponsoredLabel.textColor = .gray
        sponsoredLabel.text = ad.sponsoredBy
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.numberOfLines = 3
        bodyLabel.textColor = .gray
        bodyLabel.text = ad.text
        ctaButton.titleLabel?.font = .boldSystemFont(ofSize: 14)
        ctaButton.setTitle(ad.callToAction, for: .normal)
        iconView.contentMode = .scaleAspectFit
        iconView.clipsToBounds = true
        mainImageView.contentMode = .scaleAspectFill
        mainImageView.clipsToBounds = true
        mainImageView.isHidden = (ad.imageUrl ?? "").isEmpty
        // Hide asset views the ad doesn't carry (e.g. data-only creatives).
        iconView.isHidden = (ad.iconUrl ?? "").isEmpty
        titleLabel.isHidden = (ad.title ?? "").isEmpty
        sponsoredLabel.isHidden = (ad.sponsoredBy ?? "").isEmpty
        bodyLabel.isHidden = (ad.text ?? "").isEmpty
        ctaButton.isHidden = (ad.callToAction ?? "").isEmpty
        downloadImage(ad.iconUrl, into: iconView)
        downloadImage(ad.imageUrl, into: mainImageView)

        let titleStack = UIStackView(arrangedSubviews: [sponsoredLabel, titleLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 2
        let header = UIStackView(arrangedSubviews: [iconView, titleStack])
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .center

        iconView.translatesAutoresizingMaskIntoConstraints = false
        mainImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            mainImageView.heightAnchor.constraint(equalToConstant: 180),
        ])

        let stack = UIStackView(arrangedSubviews: [mainImageView, header, bodyLabel, ctaButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        guard ad.registerView(view: stack, clickableViews: [titleLabel, mainImageView, bodyLabel, ctaButton]) else {
            // The bid expired before the ad was shown: Prebid won't track it.
            store.remove(adId)
            forwarder.reportExpired()
            return
        }
        embed(stack)
        store.views[adId] = stack
        forwarder.watchViewability(of: stack)
        reportHeight()
    }

    /// Reports the content's height at the container's width (the screen
    /// width until Flutter has sized the view; re-run when it is).
    private func reportHeight(width: CGFloat? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let content = self.store.views[self.adId],
                  content.superview === self.container else { return }
            let width = width ?? (self.container.bounds.width > 0
                ? self.container.bounds.width
                : UIScreen.main.bounds.width)
            let height = content.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            ).height
            if height > 0, height != self.lastReportedHeight {
                self.lastReportedHeight = height
                self.methodChannel.invokeMethod("onAdSize", arguments: ["height": Double(height)])
            }
        }
    }

    private func downloadImage(_ urlString: String?, into imageView: UIImageView) {
        guard let urlString = urlString, let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { imageView.image = image }
        }.resume()
    }

}

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
