import Flutter
import UIKit
import GoogleMobileAds
import PrebidMobile
import PrebidMobileAdMobAdapters

/// PlatformView factory for AdMob-mediated banners. The rendered view is the
/// Google Mobile Ads `BannerView`; Prebid's `MediationBannerAdUnit` runs the
/// auction and passes the winning bid to AdMob via the Prebid AdMob adapter.
final class AdMobBannerAdViewFactory: NSObject, FlutterPlatformViewFactory {

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
        return AdMobBannerPlatformView(
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

/// One AdMob banner: a Google Mobile Ads `BannerView` loaded after each Prebid
/// auction of its `MediationBannerAdUnit`, reporting to Dart over
/// `prebid_mobile_sdk_admob/banner_<channelId>`.
final class AdMobBannerPlatformView: NSObject, FlutterPlatformView, GoogleMobileAds.BannerViewDelegate {

    private let gadBanner: GoogleMobileAds.BannerView
    private let methodChannel: FlutterMethodChannel
    private let adSize: CGSize
    private let adaptive: Bool
    private let dropBidProbability: Double
    private let gadRequest = Request()

    // Retained for the lifetime of the view — the auction runs through these.
    private var mediationDelegate: AdMobMediationBannerUtils?
    private var mediationAdUnit: MediationBannerAdUnit?

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        args: [String: Any]
    ) {
        let configId = args["configId"] as? String ?? ""
        let adMobAdUnitId = args["adMobAdUnitId"] as? String ?? ""
        let width = args["width"] as? Int ?? 320
        let height = args["height"] as? Int ?? 50
        let autoLoad = args["autoLoad"] as? Bool ?? true
        let refreshInterval = args["refreshIntervalSeconds"] as? Int
        // Flat [w, h, w, h, ...] list of extra Prebid request sizes.
        let flatSizes = (args["additionalSizes"] as? [NSNumber] ?? []).map { $0.intValue }
        let additionalSizes = stride(from: 0, to: flatSizes.count - 1, by: 2).map {
            CGSize(width: flatSizes[$0], height: flatSizes[$0 + 1])
        }

        adSize = CGSize(width: width, height: height)
        let isAdaptive = args["adaptive"] as? Bool ?? false
        adaptive = isAdaptive
        dropBidProbability = debugDropBidProbability(args["debugDropBidProbability"])

        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_admob/banner_\(viewChannelId(args, viewId: viewId))",
            binaryMessenger: messenger
        )

        // 1. Create the GMA banner view (the request is a stored property).
        if isAdaptive {
            // Landscape inline adaptive size for the width Flutter measured
            // (the original Prebid test app uses the full width).
            let adaptiveWidth = (args["adaptiveWidth"] as? NSNumber)?.doubleValue ?? Double(width)
            gadBanner = GoogleMobileAds.BannerView(
                adSize: GoogleMobileAds.landscapeInlineAdaptiveBanner(width: CGFloat(adaptiveWidth))
            )
        } else {
            gadBanner = GoogleMobileAds.BannerView(adSize: adSizeFor(cgSize: adSize))
        }
        gadBanner.adUnitID = adMobAdUnitId

        super.init()

        gadBanner.delegate = self
        gadBanner.rootViewController = PrebidPresenter.topViewController()

        // 2. Prebid mediation utils + ad unit.
        let mediationDelegate = AdMobMediationBannerUtils(gadRequest: gadRequest, bannerView: gadBanner)
        self.mediationDelegate = mediationDelegate
        let adUnit = MediationBannerAdUnit(
            configID: configId,
            size: adSize,
            mediationDelegate: mediationDelegate
        )
        mediationAdUnit = adUnit
        if let pos = (args["adPosition"] as? Int).flatMap({ AdPosition(rawValue: $0) }) {
            adUnit.adPosition = pos
        }
        if let config = args["impOrtbConfig"] as? String { adUnit.setImpORTBConfig(config) }
        if !additionalSizes.isEmpty { adUnit.additionalSizes = additionalSizes }
        if args["adFormats"] != nil {
            adUnit.adFormats = adFormatsFrom(args["adFormats"], isVideo: false)
        }
        // Prebid exposes the parameters get-only: they are configured in place.
        applyVideoParameters(args["videoParameters"], to: adUnit.videoParameters)
        if let interval = refreshInterval, interval > 0 {
            // Clamped by Prebid to 15–120 s.
            adUnit.refreshInterval = TimeInterval(interval)
        } else {
            // Prebid iOS refreshes every 60 s by default, and `AdUnitConfig`
            // clamps 0 up to its 15 s minimum — only a negative value is
            // stored as 0, which disables auto-refresh (parity with Android).
            adUnit.refreshInterval = -1
        }

        // Calls from PrebidBannerAdController.
        methodChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "loadAd":
                self?.load()
                result(nil)
            case "stopRefresh":
                self?.mediationAdUnit?.stopRefresh()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        if autoLoad {
            load()
        }
    }

    /// 3. Fetch demand, then let AdMob run its waterfall and render. The weak
    /// capture skips the load when the view was disposed meanwhile.
    private func load() {
        mediationAdUnit?.fetchDemand { [weak self] _ in
            onMain {
                guard let self = self else { return }
                maybeDropBid(self.dropBidProbability, from: self.gadRequest)
                self.gadBanner.rootViewController = PrebidPresenter.topViewController()
                self.gadBanner.load(self.gadRequest)
            }
        }
    }

    // iOS platform views have no dispose callback: stop answering
    // PrebidBannerAdController calls and refreshing once the view is gone.
    deinit {
        methodChannel.setMethodCallHandler(nil)
        mediationAdUnit?.stopRefresh()
    }

    func view() -> UIView {
        return gadBanner
    }

    /// Sends `event` to the widget on the main thread.
    private func send(_ event: String, _ arguments: Any? = nil) {
        onMain { [methodChannel] in methodChannel.invokeMethod(event, arguments: arguments) }
    }

    // MARK: - BannerViewDelegate

    func bannerViewDidReceiveAd(_ bannerView: GoogleMobileAds.BannerView) {
        var size = adSize
        if adaptive {
            // An inline adaptive banner reports its actual size once loaded.
            let intrinsic = bannerView.intrinsicContentSize
            let loaded = intrinsic.width > 0 && intrinsic.height > 0
                ? intrinsic
                : GoogleMobileAds.cgSize(for: bannerView.adSize)
            if loaded.width > 0 && loaded.height > 0 { size = loaded }
        }
        send("onAdSize", [
            "width": Double(size.width),
            "height": Double(size.height),
        ])
        send("onAdLoaded")
        send("onAdDisplayed")
    }

    func bannerView(
        _ bannerView: GoogleMobileAds.BannerView,
        didFailToReceiveAdWithError error: Error
    ) {
        mediationAdUnit?.adObjectDidFailToLoadAd(adObject: gadBanner, with: error)
        send("onAdFailed", PrebidErrorFormatter.describe(error))
    }

    func bannerViewDidRecordImpression(_ bannerView: GoogleMobileAds.BannerView) {
        send("onAdImpression")
    }

    func bannerViewDidRecordClick(_ bannerView: GoogleMobileAds.BannerView) {
        send("onAdClicked")
    }

    func bannerViewDidDismissScreen(_ bannerView: GoogleMobileAds.BannerView) {
        send("onAdClosed")
    }
}
