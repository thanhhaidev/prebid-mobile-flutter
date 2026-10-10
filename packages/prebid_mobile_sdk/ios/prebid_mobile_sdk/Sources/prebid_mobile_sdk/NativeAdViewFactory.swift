import Flutter
import PrebidMobile
import UIKit

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

/// A `PrebidNativeAdView`: renders the ad natively, or (custom layout) adds
/// a transparent view under the app's Flutter layout and registers it, so
/// Prebid tracks the impression and `NativeAdStore.performClick` reports taps
/// on the Flutter layout as clicks.
final class NativeAdPlatformView: NSObject, FlutterPlatformView {

    private let container = NativeAdContainer()
    let adId: Int64
    private let customLayout: Bool
    private let methodChannel: FlutterMethodChannel
    private let store: NativeAdStore
    private var lastReportedHeight: CGFloat = 0

    init(viewId: Int64, messenger: FlutterBinaryMessenger, store: NativeAdStore, args: [String: Any]) {
        adId = (args["adId"] as? NSNumber)?.int64Value ?? 0
        customLayout = args["layout"] as? String == "custom"
        // Named by the Dart widget before this view exists (AdViewChannel).
        let channelId = (args["channelId"] as? NSNumber)?.int64Value ?? viewId
        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_sdk/native_ad_\(channelId)",
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
            customLayout ? fill(content) : embed(content)
            if !customLayout { reportHeight() }
        } else if let ad = store.ads[adId], let forwarder = store.delegates[adId] {
            customLayout ? track(ad, forwarder: forwarder) : render(ad, forwarder: forwarder)
        }
    }

    /// Custom layout: registers an empty view that fills the Flutter layout.
    private func track(_ ad: NativeAd, forwarder: NativeAdEventForwarder) {
        let trackingView = UIView()
        guard ad.registerView(view: trackingView, clickableViews: [trackingView]) else {
            return expire(forwarder)
        }
        fill(trackingView)
        store.views[adId] = trackingView
        forwarder.watchViewability(of: trackingView)
    }

    /// The bid expired before the ad was shown: Prebid won't track it.
    private func expire(_ forwarder: NativeAdEventForwarder) {
        store.remove(adId)
        forwarder.reportExpired()
    }

    private func fill(_ content: UIView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
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
        downloadNativeImage(ad.iconUrl, into: iconView)
        downloadNativeImage(ad.imageUrl, into: mainImageView)

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

        guard ad.registerView(view: stack, clickableViews: [iconView, titleLabel, mainImageView, bodyLabel, ctaButton]) else {
            return expire(forwarder)
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

}
