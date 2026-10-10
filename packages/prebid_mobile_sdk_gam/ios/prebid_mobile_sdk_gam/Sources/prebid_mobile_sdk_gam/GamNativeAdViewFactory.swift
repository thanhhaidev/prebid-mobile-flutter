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

/// One GAM native ad view. It starts the auction as soon as it is created;
/// its events go over `prebid_mobile_sdk_gam/native_<channelId>`, which the
/// Dart widget listens to before creating the view.
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

    // Prebid calls adDidLogImpression once per impression tracker URL;
    // report one impression.
    private var prebidImpressionReported = false

    init(messenger: FlutterBinaryMessenger, args: [String: Any]) {
        let channelId = (args["channelId"] as? NSNumber)?.int64Value ?? 0
        self.gamAdUnitId = args["gamAdUnitId"] as? String ?? ""
        self.configId = args["configId"] as? String ?? ""
        self.customFormatId = args["customFormatId"] as? String ?? ""

        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_gam/native_\(channelId)",
            binaryMessenger: messenger
        )

        super.init()

        // Prebid merges its hb_* keys over these, so they win on conflict.
        if let targeting = gamCustomTargeting(args["customTargeting"]) {
            gamRequest.customTargeting = targeting
        }

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
        if let gpid = args["gpid"] as? String { unit.setGPID(gpid) }
        if let pbAdSlot = args["pbAdSlot"] as? String { unit.pbAdSlot = pbAdSlot }
        if let config = args["impOrtbConfig"] as? String { unit.setImpORTBConfig(config) }
        if let config = args["globalOrtbConfig"] as? String { unit.setGlobalOrtbConfig(config) } // AdUnit spells it Ortb.
        if let v = intValue(args["placementCount"]) { unit.placementCount = v }
        if let v = intValue(args["sequence"]) { unit.sequence = v }
        if let v = args["assetUrlSupport"] as? Bool { unit.asseturlsupport = v ? 1 : 0 }
        if let v = args["dUrlSupport"] as? Bool { unit.durlsupport = v ? 1 : 0 }
        if let v = args["privacy"] as? Bool { unit.privacy = v ? 1 : 0 }
        if let v = jsonDictionary(args["ext"]) { unit.ext = v }
        nativeUnit = unit

        unit.fetchDemand(adObject: gamRequest) { [weak self] resultCode in
            guard let self = self else { return }
            if resultCode == ResultCode.prebidDemandFetchSuccess {
                self.send("fetchDemandSuccess")
            } else {
                self.send("fetchDemandFailed", resultCode.dartCode)
            }

            var adTypes: [AdLoaderAdType] = [.native]
            if !self.customFormatId.isEmpty {
                adTypes.append(.customNative)
            }
            let loader = AdLoader(
                adUnitID: self.gamAdUnitId,
                rootViewController: PrebidPresenter.topViewController(),
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

    /// Sends an event to Dart on the main thread: Prebid calls some delegate
    /// methods (impressions) from a background queue, and a method channel
    /// must only be used from the main thread.
    private func send(_ method: String, _ arguments: Any? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.send(method, arguments) }
            return
        }
        methodChannel.invokeMethod(method, arguments: arguments)
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
        send("customAdLoaded")
        // Ask Prebid to extract its winning bid from the GAM custom-template
        // ad; the finder routes the answer back to this view.
        NativeAdFinder.shared.find(in: customNativeAd, for: self)
    }

    // MARK: - NativeAdLoaderDelegate (unified)

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: GoogleMobileAds.NativeAd) {
        unifiedNativeAd = nativeAd
        send("unifiedAdLoaded")
        // Unified native ads are GAM's own demand — the primary ad server wins.
        send("primaryAdWinUnified")
        renderUnified(nativeAd)
    }

    // MARK: - AdLoaderDelegate

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        send("primaryAdFailed", failure(PrebidErrorFormatter.describe(error)))
    }

    // MARK: - PrebidMobile.NativeAdDelegate

    func nativeAdLoaded(ad: PrebidMobile.NativeAd) {
        prebidNativeAd = ad
        send("nativeAdLoaded")
        ad.delegate = self
        renderPrebidNative(ad)
    }

    func nativeAdNotFound() {
        send("primaryAdWinCustom")
        renderCustomTemplate()
    }

    func nativeAdNotValid() {
        send("primaryAdWinCustom")
        renderCustomTemplate()
    }

    // MARK: - PrebidMobile.NativeAdEventDelegate

    func adDidLogImpression(ad: PrebidMobile.NativeAd) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.prebidImpressionReported else { return }
            self.prebidImpressionReported = true
            self.send("onAdImpression")
        }
    }

    func adWasClicked(ad: PrebidMobile.NativeAd) {
        send("onAdClicked")
    }

    func adDidExpire(ad: PrebidMobile.NativeAd) {
        send("onAdExpired")
    }

    // MARK: - GoogleMobileAds.NativeAdDelegate (unified)

    func nativeAdDidRecordImpression(_ nativeAd: GoogleMobileAds.NativeAd) {
        send("onAdImpression")
    }

    func nativeAdDidRecordClick(_ nativeAd: GoogleMobileAds.NativeAd) {
        send("onAdClicked")
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
        // Prebid tracks impressions on the whole container; the same views as
        // on Android are clickable. Labels and images ignore touches unless
        // enabled.
        let clickableViews: [UIView] = [iconView, titleLabel, mainImageView, bodyLabel, ctaButton]
        clickableViews.forEach { $0.isUserInteractionEnabled = true }
        if !ad.registerView(view: container, clickableViews: clickableViews) {
            // Prebid refuses an expired ad (the bid outlived `bid.exp` while
            // GAM loaded); nothing would be tracked, so report the expiry.
            send("onAdExpired")
        }
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
        DispatchQueue.main.async { [weak self] in
            let height = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
            if height > 0 {
                self?.send("onAdSize", ["height": Double(height)])
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

/// Runs `Utils.shared.findNative` for native views one request at a time.
///
/// `Utils.shared` reports to a single, process-wide weak `delegate`, so two
/// views asking at once would get each other's results. The finder is that
/// delegate: it queues requests, keeps one in flight, routes each answer to
/// the view that asked, and skips requests whose view is gone.
final class NativeAdFinder: NSObject, PrebidMobile.NativeAdDelegate {

    static let shared = NativeAdFinder()

    private final class Request {
        weak var owner: PrebidMobile.NativeAdDelegate?
        let adObject: AnyObject

        init(owner: PrebidMobile.NativeAdDelegate, adObject: AnyObject) {
            self.owner = owner
            self.adObject = adObject
        }
    }

    private var queue: [Request] = []
    private var current: Request?

    /// Looks for a Prebid native ad in `adObject` (a GAM custom-format ad)
    /// and reports the result to `owner`, on the main thread.
    func find(in adObject: AnyObject, for owner: PrebidMobile.NativeAdDelegate) {
        queue.append(Request(owner: owner, adObject: adObject))
        next()
    }

    private func next() {
        guard current == nil else { return }
        while !queue.isEmpty {
            let request = queue.removeFirst()
            guard request.owner != nil else { continue }
            current = request
            // Set right before each call: another integration may have
            // replaced the shared delegate meanwhile.
            Utils.shared.delegate = self
            Utils.shared.findNative(adObject: request.adObject)
            if current === request {
                // Prebid answers a custom-format ad synchronously today; if
                // it ever doesn't answer, don't hold up the other views.
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self, weak request] in
                    guard let self = self, let request = request, self.current === request else { return }
                    self.finish { $0.nativeAdNotFound() }
                }
            }
            return
        }
    }

    /// Hands the in-flight request's answer to its view, then starts the next.
    private func finish(_ deliver: (PrebidMobile.NativeAdDelegate) -> Void) {
        guard let request = current else { return }
        current = nil
        if let owner = request.owner { deliver(owner) }
        next()
    }

    func nativeAdLoaded(ad: PrebidMobile.NativeAd) {
        finish { $0.nativeAdLoaded(ad: ad) }
    }

    func nativeAdNotFound() {
        finish { $0.nativeAdNotFound() }
    }

    func nativeAdNotValid() {
        finish { $0.nativeAdNotValid() }
    }
}
