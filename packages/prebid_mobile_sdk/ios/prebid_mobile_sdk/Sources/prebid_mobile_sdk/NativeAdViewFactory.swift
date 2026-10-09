import Flutter
import UIKit
import PrebidMobile

/// Loaded In-App native ads, keyed by the Dart ad id, so a
/// `NativeAdPlatformView` can render and register the ad for tracking.
enum NativeAdStore {
    static var ads: [Int64: NativeAd] = [:]

    /// The rendered, registered view of each ad. `NativeAd.registerView` only
    /// accepts one view per ad, so a platform view re-created for the same ad
    /// (e.g. after scrolling out of a list and back) reuses this one.
    static var views: [Int64: UIView] = [:]

    /// Event delegates, held strongly: Prebid holds the ad's delegate weakly.
    static var delegates: [Int64: NativeAdEventForwarder] = [:]

    static func remove(_ adId: Int64) {
        ads.removeValue(forKey: adId)
        delegates.removeValue(forKey: adId)
        views.removeValue(forKey: adId)?.removeFromSuperview()
    }
}

/// PlatformView factory for `PrebidNativeAdView`: renders a loaded `NativeAd`
/// natively and calls `registerView` so Prebid tracks viewability-based
/// impressions and clicks.
class NativeAdViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger
    private let flutterApi: AdFlutterApi

    init(messenger: FlutterBinaryMessenger, flutterApi: AdFlutterApi) {
        self.messenger = messenger
        self.flutterApi = flutterApi
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
            flutterApi: flutterApi,
            args: args as? [String: Any] ?? [:]
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class NativeAdPlatformView: NSObject, FlutterPlatformView {

    private let container = UIView()
    private let adId: Int64
    private let methodChannel: FlutterMethodChannel
    private let flutterApi: AdFlutterApi

    init(viewId: Int64, messenger: FlutterBinaryMessenger, flutterApi: AdFlutterApi, args: [String: Any]) {
        adId = (args["adId"] as? NSNumber)?.int64Value ?? 0
        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_flutter/native_ad_\(viewId)",
            binaryMessenger: messenger
        )
        self.flutterApi = flutterApi
        super.init()
        if let content = NativeAdStore.views[adId] {
            content.removeFromSuperview()
            embed(content)
            reportHeight(of: content)
        } else if let ad = NativeAdStore.ads[adId] {
            render(ad)
        }
    }

    deinit {
        // Keep the registered view for a re-created platform view;
        // NativeAdStore.remove releases it.
        // A newer platform view may already have taken it.
        if let content = NativeAdStore.views[adId], content.superview === container {
            content.removeFromSuperview()
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

    private func render(_ ad: NativeAd) {
        let forwarder = NativeAdEventForwarder(adId: adId, flutterApi: flutterApi)
        NativeAdStore.delegates[adId] = forwarder
        ad.delegate = forwarder

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

        embed(stack)
        NativeAdStore.views[adId] = stack
        _ = ad.registerView(view: stack, clickableViews: [titleLabel, mainImageView, bodyLabel, ctaButton])
        reportHeight(of: stack)
    }

    private func reportHeight(of view: UIView) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let width = self.container.bounds.width > 0
                ? self.container.bounds.width
                : UIScreen.main.bounds.width
            let height = view.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            ).height
            if height > 0 {
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
class NativeAdEventForwarder: NSObject, NativeAdEventDelegate {
    private let adId: Int64
    private let flutterApi: AdFlutterApi

    init(adId: Int64, flutterApi: AdFlutterApi) {
        self.adId = adId
        self.flutterApi = flutterApi
    }

    // Prebid calls this once per impression tracker URL; report one impression.
    private var impressionReported = false

    func adDidLogImpression(ad: NativeAd) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.impressionReported else { return }
            self.impressionReported = true
            self.send("onAdImpression")
        }
    }

    func adWasClicked(ad: NativeAd) {
        send("onAdClicked")
    }

    func adDidExpire(ad: NativeAd) {
        send("onAdExpired")
    }

    private func send(_ name: String) {
        DispatchQueue.main.async { [adId, flutterApi] in
            flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: name)) { _ in }
        }
    }
}
