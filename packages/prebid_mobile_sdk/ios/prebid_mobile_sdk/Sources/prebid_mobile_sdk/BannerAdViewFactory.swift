import Flutter
import UIKit
import PrebidMobile

class BannerAdViewFactory: NSObject, FlutterPlatformViewFactory {
    
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

class BannerAdPlatformView: NSObject, FlutterPlatformView, BannerViewDelegate, BannerViewVideoPlaybackDelegate {

    private let bannerView: BannerView
    private let methodChannel: FlutterMethodChannel

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

        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_flutter/banner_ad_\(viewId)",
            binaryMessenger: messenger
        )

        bannerView = BannerView(
            frame: CGRect(origin: .zero, size: adSize),
            configID: configId,
            adSize: adSize
        )

        super.init()

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
        if let impOrtbConfig = impOrtbConfig { bannerView.setImpORTBConfig(impOrtbConfig) }

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
        methodChannel.invokeMethod("onAdSize", arguments: [
            "width": Double(adSize.width),
            "height": Double(adSize.height),
        ])
        // iOS reports load and render as one event; Android splits them into
        // onAdLoaded + onAdDisplayed, so emit both here for cross-platform parity.
        methodChannel.invokeMethod("onAdLoaded", arguments: nil)
        methodChannel.invokeMethod("onAdDisplayed", arguments: nil)
    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWith error: Error) {
        methodChannel.invokeMethod("onAdFailed", arguments: PrebidErrorFormatter.describe(error))
    }
    
    func bannerViewWillPresentModal(_ bannerView: BannerView) {
        methodChannel.invokeMethod("onAdClicked", arguments: nil)
    }
    
    func bannerViewDidDismissModal(_ bannerView: BannerView) {
        methodChannel.invokeMethod("onAdClosed", arguments: nil)
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
