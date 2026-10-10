import Flutter
import PrebidMobile
import UIKit

final class BannerAdViewFactory: NSObject, FlutterPlatformViewFactory {

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
        return BannerAdPlatformView(
            frame: frame,
            viewId: viewId,
            messenger: messenger,
            args: args as? [String: Any] ?? [:]
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

final class BannerAdPlatformView: NSObject, FlutterPlatformView, BannerViewDelegate, BannerViewVideoPlaybackDelegate {

    private let bannerView: BannerView
    private let methodChannel: FlutterMethodChannel
    /// Between willPresentModal and didDismissModal (see willLeaveApplication).
    private var isModalOpen = false

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        args: [String: Any]
    ) {
        let configId = args["configId"] as? String ?? ""
        let width = args["width"] as? Int ?? 320
        let height = args["height"] as? Int ?? 50
        let isVideo = args["isVideo"] as? Bool ?? false
        let autoLoad = args["autoLoad"] as? Bool ?? true
        let refreshInterval = args["refreshIntervalSeconds"] as? Int
        let adFormats = args["adFormats"] as? [String]
        let pbAdSlot = args["pbAdSlot"] as? String
        let impOrtbConfig = args["impOrtbConfig"] as? String
        let videoPlacement = args["videoPlacementType"] as? String

        let adSize = CGSize(width: width, height: height)

        // Named by the Dart widget before this view exists (AdViewChannel).
        let channelId = (args["channelId"] as? NSNumber)?.int64Value ?? viewId
        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_sdk/banner_ad_\(channelId)",
            binaryMessenger: messenger
        )

        bannerView = BannerView(
            frame: CGRect(origin: .zero, size: adSize),
            configID: configId,
            adSize: adSize
        )

        super.init()
        StoredAuctionResponseKeeper.protect(bannerView)

        if let flat = args["additionalSizes"] as? [Int], flat.count >= 2 {
            bannerView.additionalSizes = stride(from: 0, to: flat.count - 1, by: 2).map {
                CGSize(width: flat[$0], height: flat[$0 + 1])
            }
        }

        if let adFormats = adFormats {
            // Multiformat banner (Prebid 3.4): banner and/or video in one request.
            var formats: Set<AdFormat> = []
            if adFormats.contains("banner") { formats.insert(.banner) }
            if adFormats.contains("video") { formats.insert(.video) }
            if !formats.isEmpty { bannerView.adFormats = formats }
        } else if isVideo {
            bannerView.adFormats = [.video]
        }
        // Same default as Android: a video banner is in-banner placement.
        if bannerView.adFormats.contains(.video) {
            bannerView.videoParameters.placement =
                videoPlacement.flatMap(signalsPlacement) ?? .InBanner
        }
        if let pbAdSlot = pbAdSlot { bannerView.adUnitConfig.setPbAdSlot(pbAdSlot) }
        if let pos = (args["adPosition"] as? Int).flatMap({ AdPosition(rawValue: $0) }) {
            bannerView.adPosition = pos
        }
        if let raw = args["videoParameters"] as? [String: Any] {
            applyVideoParameters(raw, to: bannerView.videoParameters)
        }
        if let impOrtbConfig = impOrtbConfig { bannerView.setImpORTBConfig(impOrtbConfig) }
        if let globalOrtbConfig = args["globalOrtbConfig"] as? String {
            bannerView.setGlobalORTBConfig(globalOrtbConfig)
        }

        // iOS defaults to a 60s refresh (Android: none) and clamps 0 up to 15s;
        // a negative value is what disables it.
        if let interval = refreshInterval, interval > 0 {
            bannerView.refreshInterval = TimeInterval(interval)
        } else {
            bannerView.refreshInterval = -1
        }

        bannerView.delegate = self
        bannerView.videoPlaybackDelegate = self

        // Calls from PrebidBannerAdController.
        methodChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "loadAd":
                self?.bannerView.loadAd()
                result(nil)
            case "stopRefresh":
                self?.bannerView.stopRefresh()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        if autoLoad {
            bannerView.loadAd()
        }
    }

    deinit {
        methodChannel.setMethodCallHandler(nil)
        bannerView.stopRefresh()
    }

    func view() -> UIView {
        return bannerView
    }

    // MARK: - BannerViewDelegate

    func bannerViewPresentationController() -> UIViewController? {
        return PrebidPresenter.topViewController()
    }

    func bannerView(_ bannerView: BannerView, didReceiveAdWithAdSize adSize: CGSize) {
        // Report the rendered creative size so the Flutter widget can size the
        // slot dynamically to whatever the SDK returns (no fixed frame).
        methodChannel.invokeMethod(
            "onAdSize",
            arguments: [
                "width": Double(adSize.width),
                "height": Double(adSize.height),
            ])
        methodChannel.invokeMethod("onAdLoaded", arguments: bannerView.lastBidResponse?.winningBidPayload)
    }

    // Fired once the creative is on screen and its impression is tracked
    // (BannerView.didDisplayAd), like Android's onAdDisplayed.
    func bannerViewDidDisplay(_ bannerView: BannerView) {
        methodChannel.invokeMethod("onAdDisplayed", arguments: nil)
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWith error: Error) {
        methodChannel.invokeMethod("onAdFailed", arguments: ["error": PrebidErrorFormatter.describe(error)])
    }

    func bannerViewWillPresentModal(_ bannerView: BannerView) {
        isModalOpen = true
        methodChannel.invokeMethod("onAdClicked", arguments: nil)
    }

    func bannerViewDidDismissModal(_ bannerView: BannerView) {
        isModalOpen = false
        methodChannel.invokeMethod("onAdClosed", arguments: nil)
    }

    // Prebid reports leaving the app from a modal it opened (in-app browser
    // "Open in Safari", expanded MRAID ad), whose click willPresentModal has
    // already reported; only a leave with no modal open is a new click.
    func bannerViewWillLeaveApplication(_ bannerView: BannerView) {
        guard !isModalOpen else { return }
        methodChannel.invokeMethod("onAdClicked", arguments: nil)
    }

    func bannerViewDidExpire(_ bannerView: BannerView) {
        methodChannel.invokeMethod("onAdExpired", arguments: nil)
    }

    // MARK: - BannerViewVideoPlaybackDelegate

    func videoPlaybackDidPause(_ banner: BannerView) {
        methodChannel.invokeMethod("onVideoPaused", arguments: nil)
    }

    func videoPlaybackDidResume(_ banner: BannerView) {
        methodChannel.invokeMethod("onVideoResumed", arguments: nil)
    }

    func videoPlaybackWasMuted(_ banner: BannerView) {
        methodChannel.invokeMethod("onVideoMuted", arguments: nil)
    }

    func videoPlaybackWasUnmuted(_ banner: BannerView) {
        methodChannel.invokeMethod("onVideoUnmuted", arguments: nil)
    }

    func videoPlaybackDidComplete(_ banner: BannerView) {
        methodChannel.invokeMethod("onVideoCompleted", arguments: nil)
    }
}

func signalsPlacement(_ name: String) -> Signals.Placement? {
    switch name {
    case "inBanner": return .InBanner
    case "inArticle": return .InArticle
    case "inFeed": return .InFeed
    default: return nil
    }
}

/// Prebid's `BannerView` sets the global `storedAuctionResponse` to nil when
/// it deallocates, so disposing any banner would drop the response the app
/// set for every later request. The app's value is kept on `Prebid.shared`
/// and each banner restores it after its own `deinit`: associated objects
/// are released once the owner's `deinit` has run.
enum StoredAuctionResponseKeeper {
    // A selector is unique per process, so every plugin module gets this key.
    private static let valueKey = unsafeBitCast(
        sel_registerName("prebidFlutterStoredAuctionResponse"), to: UnsafeRawPointer.self
    )
    private static var restorerKey: UInt8 = 0

    static func remember(_ value: String?) {
        objc_setAssociatedObject(Prebid.shared, valueKey, value, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    }

    static func protect(_ banner: UIView) {
        objc_setAssociatedObject(banner, &restorerKey, Restorer(), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private final class Restorer {
        deinit {
            if let value = objc_getAssociatedObject(Prebid.shared, StoredAuctionResponseKeeper.valueKey) as? String {
                Prebid.shared.storedAuctionResponse = value
            }
        }
    }
}

extension BidResponse {
    /// The winning bid, as sent with a banner's `onAdLoaded`.
    var winningBidPayload: [String: Any]? {
        guard let bid = winningBid else { return nil }
        let keywords = targetingInfo ?? [:]
        return [
            "price": Double(bid.price),
            "bidder": keywords["hb_bidder"] as Any,
            "width": Int(bid.size.width),
            "height": Int(bid.size.height),
            "targetingKeywords": keywords,
        ]
    }
}
