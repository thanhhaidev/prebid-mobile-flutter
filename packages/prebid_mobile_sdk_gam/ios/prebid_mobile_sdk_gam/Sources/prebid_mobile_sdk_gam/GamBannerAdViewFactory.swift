import Flutter
import UIKit
import GoogleMobileAds
import PrebidMobile
import PrebidMobileGAMEventHandlers

/// PlatformView factory for GAM-rendered banners. Mirrors the core
/// BannerAdViewFactory but builds the BannerView with a `GAMBannerEventHandler`
/// so Google Ad Manager renders the ad.
class GamBannerAdViewFactory: NSObject, FlutterPlatformViewFactory {

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
        return GamBannerPlatformView(
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

class GamBannerPlatformView: NSObject, FlutterPlatformView, PrebidMobile.BannerViewDelegate,
    BannerViewVideoPlaybackDelegate {

    private let bannerView: PrebidMobile.BannerView
    private let methodChannel: FlutterMethodChannel

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        args: [String: Any]
    ) {
        let configId = args["configId"] as? String ?? ""
        let gamAdUnitId = args["gamAdUnitId"] as? String ?? ""
        let width = args["width"] as? Int ?? 320
        let height = args["height"] as? Int ?? 50
        let isVideo = args["isVideo"] as? Bool ?? false
        let autoLoad = args["autoLoad"] as? Bool ?? true
        let refreshInterval = args["refreshIntervalSeconds"] as? Int
        let videoPlacement = args["videoPlacementType"] as? String
        let adFormats = args["adFormats"] as? [String]
        let pbAdSlot = args["pbAdSlot"] as? String
        let impOrtbConfig = args["impOrtbConfig"] as? String

        let adSize = CGSize(width: width, height: height)
        // Flat [w, h, w, h, ...] list of extra sizes for a multisize banner.
        let flatSizes = (args["additionalSizes"] as? [NSNumber] ?? []).map { $0.intValue }
        let additionalSizes = stride(from: 0, to: flatSizes.count - 1, by: 2).map {
            CGSize(width: flatSizes[$0], height: flatSizes[$0 + 1])
        }

        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_gam/banner_\(viewId)",
            binaryMessenger: messenger
        )

        let eventHandler = GAMBannerEventHandler(
            adUnitID: gamAdUnitId,
            validGADAdSizes: ([adSize] + additionalSizes).map { nsValue(for: adSizeFor(cgSize: $0)) }
        )
        if let targeting = gamCustomTargeting(args["customTargeting"]) {
            // Prebid 3.4: app custom targeting on the GAM request; Prebid's
            // hb_* keys still take precedence.
            eventHandler.adManagerRequestConfiguration = { request in
                var merged = request.customTargeting ?? [:]
                targeting.forEach { merged[$0.key] = $0.value }
                request.customTargeting = merged
            }
        }
        // Takes the primary size from the event handler and derives
        // `additionalSizes` from its remaining valid sizes.
        bannerView = PrebidMobile.BannerView(configID: configId, eventHandler: eventHandler)

        super.init()
        StoredAuctionResponseKeeper.protect(bannerView)

        if let pos = (args["adPosition"] as? Int).flatMap({ AdPosition(rawValue: $0) }) {
            bannerView.adPosition = pos
        }

        if let adFormats = adFormats {
            // Multiformat banner (Prebid 3.4): banner and/or video in one request.
            var formats: Set<PrebidMobile.AdFormat> = []
            if adFormats.contains("banner") { formats.insert(.banner) }
            if adFormats.contains("video") { formats.insert(.video) }
            if !formats.isEmpty { bannerView.adFormats = formats }
        } else if isVideo {
            bannerView.adFormats = [.video]
        }
        if bannerView.adFormats.contains(.video) {
            switch videoPlacement {
            case "inArticle": bannerView.videoParameters.placement = .InArticle
            case "inFeed": bannerView.videoParameters.placement = .InFeed
            default: bannerView.videoParameters.placement = .InBanner
            }
        }
        // `videoParameters` is get-only: configure it in place. An explicit
        // `placement` here overrides `videoPlacementType`.
        applyVideoParameters(args["videoParameters"], to: bannerView.videoParameters)
        if let pbAdSlot = pbAdSlot { bannerView.adUnitConfig.setPbAdSlot(pbAdSlot) }
        if let impOrtbConfig = impOrtbConfig { bannerView.setImpORTBConfig(impOrtbConfig) }

        if let interval = refreshInterval, interval > 0 {
            bannerView.refreshInterval = TimeInterval(interval)
        } else {
            // Prebid iOS refreshes every 60 s by default, and `AdUnitConfig`
            // clamps 0 up to its 15 s minimum — only a negative value is
            // stored as 0, which disables auto-refresh (parity with Android).
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

    // iOS platform views have no dispose callback: stop answering
    // PrebidBannerAdController calls and refreshing once the view is gone.
    deinit {
        methodChannel.setMethodCallHandler(nil)
        bannerView.stopRefresh()
    }

    func view() -> UIView {
        return bannerView
    }

    // MARK: - BannerViewDelegate

    func bannerViewPresentationController() -> UIViewController? {
        return topViewController()
    }

    func bannerView(_ bannerView: PrebidMobile.BannerView, didReceiveAdWithAdSize adSize: CGSize) {
        methodChannel.invokeMethod("onAdSize", arguments: [
            "width": Double(adSize.width),
            "height": Double(adSize.height),
        ])
        // iOS reports load and render as one event; Android splits them into
        // onAdLoaded + onAdDisplayed, so emit both here for cross-platform parity.
        methodChannel.invokeMethod("onAdLoaded", arguments: nil)
        methodChannel.invokeMethod("onAdDisplayed", arguments: nil)
    }

    func bannerView(_ bannerView: PrebidMobile.BannerView, didFailToReceiveAdWith error: Error) {
        methodChannel.invokeMethod("onAdFailed", arguments: error.localizedDescription)
    }

    func bannerViewWillPresentModal(_ bannerView: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onAdClicked", arguments: nil)
    }

    func bannerViewDidDismissModal(_ bannerView: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onAdClosed", arguments: nil)
    }

    func bannerViewDidExpire(_ bannerView: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onAdExpired", arguments: nil)
    }

    // MARK: - BannerViewVideoPlaybackDelegate

    func videoPlaybackDidPause(_ banner: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onVideoPaused", arguments: nil)
    }

    func videoPlaybackDidResume(_ banner: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onVideoResumed", arguments: nil)
    }

    func videoPlaybackWasMuted(_ banner: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onVideoMuted", arguments: nil)
    }

    func videoPlaybackWasUnmuted(_ banner: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onVideoUnmuted", arguments: nil)
    }

    func videoPlaybackDidComplete(_ banner: PrebidMobile.BannerView) {
        methodChannel.invokeMethod("onVideoCompleted", arguments: nil)
    }
}

/// Prebid's `BannerView` sets the global `storedAuctionResponse` to nil when
/// it deallocates. The core plugin keeps the app's value on `Prebid.shared`
/// (see its `StoredAuctionResponseKeeper`); each banner restores it after its
/// own `deinit`: associated objects are released once the owner's `deinit`
/// has run.
enum StoredAuctionResponseKeeper {
    // Same key as the core plugin: a selector is unique per process.
    private static let valueKey = unsafeBitCast(
        sel_registerName("prebidFlutterStoredAuctionResponse"), to: UnsafeRawPointer.self
    )
    private static var restorerKey: UInt8 = 0

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
