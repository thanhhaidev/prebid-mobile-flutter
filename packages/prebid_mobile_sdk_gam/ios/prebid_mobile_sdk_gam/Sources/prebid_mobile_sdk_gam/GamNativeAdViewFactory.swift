import Flutter
import UIKit
import GoogleMobileAds
import PrebidMobile

/// PlatformView factory for GAM Original-API native ads (custom-template +
/// unified). Prebid runs the auction, GAM resolves the line item, and
/// `Utils.shared.findNative` extracts the Prebid winning bid for app-side
/// rendering — matching Prebid's reference GAM native integration.
final class GamNativeAdViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return GamNativePlatformView(
            messenger: messenger,
            args: args as? [String: Any] ?? [:]
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

final class GamNativePlatformView: NSObject, FlutterPlatformView,
    AdLoaderDelegate, CustomNativeAdLoaderDelegate, NativeAdLoaderDelegate,
    PrebidMobile.NativeAdDelegate, PrebidMobile.NativeAdEventDelegate,
    GoogleMobileAds.NativeAdDelegate {

    private let container = UIView()
    private let methodChannel: FlutterMethodChannel
    private let gamAdUnitId: String
    private let configId: String
    private let customFormatId: String

    private let gamRequest = AdManagerRequest()
    private var nativeUnit: NativeRequest?
    private var adLoader: AdLoader?

    // Strong references: Prebid keeps only weak references to the native ad and
    // its event delegate, so these must be retained for impressions/clicks.
    private var prebidNativeAd: PrebidMobile.NativeAd?
    private var unifiedNativeAd: GoogleMobileAds.NativeAd?
    private var customNativeAd: CustomNativeAd?

    init(messenger: FlutterBinaryMessenger, args: [String: Any]) {
        let logicalId = args["logicalId"] as? Int ?? 0
        self.gamAdUnitId = args["gamAdUnitId"] as? String ?? ""
        self.configId = args["configId"] as? String ?? ""
        self.customFormatId = args["customFormatId"] as? String ?? ""

        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_gam/native_\(logicalId)",
            binaryMessenger: messenger
        )

        super.init()

        let unit = NativeRequest(configId: configId, assets: nativeAssetsFrom(args["assets"]) ?? Self.requestAssets)
        unit.context = ContextType.Social
        unit.placementType = PlacementType.FeedContent
        unit.contextSubType = ContextSubType.Social
        if let v = args["context"] as? Int { unit.context = ContextType(integerLiteral: v) }
        if let v = args["contextSubType"] as? Int { unit.contextSubType = ContextSubType(integerLiteral: v) }
        if let v = args["placementType"] as? Int { unit.placementType = PlacementType(integerLiteral: v) }
        unit.eventtrackers = nativeTrackersFrom(args["eventTrackers"]) ?? [
            NativeEventTracker(event: EventType.Impression, methods: [EventTracking.Image, EventTracking.js])
        ]
        nativeUnit = unit

        unit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            guard let self = self else { return }
            if resultCode == ResultCode.prebidDemandFetchSuccess {
                self.methodChannel.invokeMethod("fetchDemandSuccess", arguments: nil)
            } else {
                self.methodChannel.invokeMethod("fetchDemandFailed", arguments: resultCode.dartCode)
            }

            var adTypes: [AdLoaderAdType] = [.native]
            if !self.customFormatId.isEmpty {
                adTypes.append(.customNative)
            }
            let loader = AdLoader(
                adUnitID: self.gamAdUnitId,
                rootViewController: topViewController(),
                adTypes: adTypes,
                options: []
            )
            loader.delegate = self
            self.adLoader = loader
            loader.load(self.gamRequest)
        }
    }

    func view() -> UIView {
        return container
    }

    private static var requestAssets: [NativeAsset] {
        let title = NativeAssetTitle(length: 90, required: true)
        let icon = NativeAssetImage(minimumWidth: 20, minimumHeight: 20, required: true)
        icon.type = ImageAsset.Icon
        let image = NativeAssetImage(minimumWidth: 200, minimumHeight: 200, required: true)
        image.type = ImageAsset.Main
        let sponsored = NativeAssetData(type: DataAsset.sponsored, required: true)
        let body = NativeAssetData(type: DataAsset.description, required: true)
        let cta = NativeAssetData(type: DataAsset.ctatext, required: true)
        return [title, icon, image, sponsored, body, cta]
    }

    // MARK: - CustomNativeAdLoaderDelegate

    func customNativeAdFormatIDs(for adLoader: AdLoader) -> [String] {
        return customFormatId.isEmpty ? [] : [customFormatId]
    }

    func adLoader(_ adLoader: AdLoader, didReceive customNativeAd: CustomNativeAd) {
        self.customNativeAd = customNativeAd
        methodChannel.invokeMethod("customAdLoaded", arguments: nil)
        // Ask Prebid to extract its winning bid from the GAM custom-template ad.
        Utils.shared.delegate = self
        Utils.shared.findNative(adObject: customNativeAd)
    }

    // MARK: - NativeAdLoaderDelegate (unified)

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: GoogleMobileAds.NativeAd) {
        unifiedNativeAd = nativeAd
        methodChannel.invokeMethod("unifiedAdLoaded", arguments: nil)
        // Unified native ads are GAM's own demand — the primary ad server wins.
        methodChannel.invokeMethod("primaryAdWinUnified", arguments: nil)
        renderUnified(nativeAd)
    }

    // MARK: - AdLoaderDelegate

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        methodChannel.invokeMethod("primaryAdFailed", arguments: error.localizedDescription)
    }

    // MARK: - PrebidMobile.NativeAdDelegate

    func nativeAdLoaded(ad: PrebidMobile.NativeAd) {
        prebidNativeAd = ad
        methodChannel.invokeMethod("nativeAdLoaded", arguments: nil)
        ad.delegate = self
        renderPrebidNative(ad)
    }

    func nativeAdNotFound() {
        methodChannel.invokeMethod("primaryAdWinCustom", arguments: nil)
        renderCustomTemplate()
    }

    func nativeAdNotValid() {
        methodChannel.invokeMethod("primaryAdWinCustom", arguments: nil)
        renderCustomTemplate()
    }

    // MARK: - PrebidMobile.NativeAdEventDelegate

    // Prebid calls this once per impression tracker URL; report one impression.
    private var prebidImpressionReported = false

    func adDidLogImpression(ad: PrebidMobile.NativeAd) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.prebidImpressionReported else { return }
            self.prebidImpressionReported = true
            self.methodChannel.invokeMethod("onAdImpression", arguments: nil)
        }
    }

    func adWasClicked(ad: PrebidMobile.NativeAd) {
        methodChannel.invokeMethod("onAdClicked", arguments: nil)
    }

    func adDidExpire(ad: PrebidMobile.NativeAd) {
        methodChannel.invokeMethod("onAdExpired", arguments: nil)
    }

    // MARK: - GoogleMobileAds.NativeAdDelegate (unified)

    func nativeAdDidRecordImpression(_ nativeAd: GoogleMobileAds.NativeAd) {
        methodChannel.invokeMethod("onAdImpression", arguments: nil)
    }

    func nativeAdDidRecordClick(_ nativeAd: GoogleMobileAds.NativeAd) {
        methodChannel.invokeMethod("onAdClicked", arguments: nil)
    }

    // MARK: - Rendering

    private func renderPrebidNative(_ ad: PrebidMobile.NativeAd) {
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

        let stack = mountStack([mainImageView, header, bodyLabel, ctaButton])
        // Register the whole native container so Prebid tracks impressions/clicks.
        ad.registerView(view: container, clickableViews: [ctaButton])
        reportHeight(of: stack)
    }

    private func renderUnified(_ nativeAd: GoogleMobileAds.NativeAd) {
        let nativeAdView = GoogleMobileAds.NativeAdView()
        let iconView = UIImageView()
        let mediaView = MediaView()
        let headlineLabel = UILabel()
        let bodyLabel = UILabel()
        let ctaButton = UIButton(type: .system)

        headlineLabel.font = .boldSystemFont(ofSize: 15)
        headlineLabel.numberOfLines = 2
        headlineLabel.text = nativeAd.headline
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.numberOfLines = 3
        bodyLabel.textColor = .gray
        bodyLabel.text = nativeAd.body
        ctaButton.titleLabel?.font = .boldSystemFont(ofSize: 14)
        ctaButton.setTitle(nativeAd.callToAction, for: .normal)
        ctaButton.isUserInteractionEnabled = false
        iconView.contentMode = .scaleAspectFit
        iconView.image = nativeAd.icon?.image
        mediaView.contentMode = .scaleAspectFill
        mediaView.mediaContent = nativeAd.mediaContent
        nativeAd.delegate = self

        let header = UIStackView(arrangedSubviews: [iconView, headlineLabel])
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .center
        iconView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            mediaView.heightAnchor.constraint(equalToConstant: 180),
        ])

        let stack = UIStackView(arrangedSubviews: [mediaView, header, bodyLabel, ctaButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
        ])
        nativeAdView.mediaView = mediaView
        nativeAdView.iconView = iconView
        nativeAdView.headlineView = headlineLabel
        nativeAdView.bodyView = bodyLabel
        nativeAdView.callToActionView = ctaButton
        nativeAdView.nativeAd = nativeAd

        container.subviews.forEach { $0.removeFromSuperview() }
        container.addSubview(nativeAdView)
        NSLayoutConstraint.activate([
            nativeAdView.topAnchor.constraint(equalTo: container.topAnchor),
            nativeAdView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            nativeAdView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            nativeAdView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        reportHeight(of: nativeAdView)
    }

    private func renderCustomTemplate() {
        if let ad = customNativeAd {
            let label = UILabel()
            label.font = .boldSystemFont(ofSize: 15)
            label.numberOfLines = 0
            label.text = ad.string(forKey: "title") ?? "Ad"
            _ = mountStack([label])
            ad.recordImpression()
        }
    }

    /// Adds a padded vertical stack filling the container, returns the stack.
    @discardableResult
    private func mountStack(_ views: [UIView]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        container.subviews.forEach { $0.removeFromSuperview() }
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return stack
    }

    private func reportHeight(of view: UIView) {
        DispatchQueue.main.async {
            let height = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
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
