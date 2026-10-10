import AppLovinSDK
import Flutter
import PrebidMobile
import PrebidMobileMAXAdapters
import UIKit

/// PlatformView factory for AppLovin MAX-mediated banners. The rendered view is
/// the MAX `MAAdView`; Prebid's `MediationBannerAdUnit` runs the auction and
/// passes the winning bid to MAX via the Prebid MAX adapter.
final class MaxBannerAdViewFactory: NSObject, FlutterPlatformViewFactory {

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
        return MaxBannerPlatformView(
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

/// One MAX banner: a `MAAdView` that the Prebid `MediationBannerAdUnit`'s
/// auction bids into. Events go to the widget over
/// `prebid_mobile_sdk_max/banner_<channelId>`.
final class MaxBannerPlatformView: NSObject, FlutterPlatformView, MAAdViewAdDelegate, MAAdRevenueDelegate {

    private let maxAdBannerView: MAAdView
    private let methodChannel: FlutterMethodChannel
    private let adSize: CGSize
    /// The MAX view's size: `adSize`, or the adaptive banner size.
    private let viewSize: CGSize
    private let dropBidProbability: Double

    // Retained for the lifetime of the view — the auction runs through these.
    private var mediationDelegate: MAXMediationBannerUtils?
    private var mediationAdUnit: MediationBannerAdUnit?

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        args: [String: Any]
    ) {
        let configId = args["configId"] as? String ?? ""
        let maxAdUnitId = args["maxAdUnitId"] as? String ?? ""
        let width = args["width"] as? Int ?? 320
        let height = args["height"] as? Int ?? 50
        let autoLoad = args["autoLoad"] as? Bool ?? true
        let refreshInterval = args["refreshIntervalSeconds"] as? Int
        // Flat [w, h, w, h, ...] list of extra Prebid request sizes.
        let flatSizes = (args["additionalSizes"] as? [NSNumber] ?? []).map { $0.intValue }
        let additionalSizes = stride(from: 0, to: flatSizes.count - 1, by: 2).map {
            CGSize(width: flatSizes[$0], height: flatSizes[$0 + 1])
        }
        let isMrec = width == 300 && height == 250
        // Adaptive banner (banner format only): full measured width, at the
        // height MAX computes for it — as the original Prebid test app does.
        let adaptive = (args["adaptive"] as? Bool ?? false) && !isMrec

        adSize = CGSize(width: width, height: height)
        if adaptive {
            let adaptiveWidth = CGFloat((args["adaptiveWidth"] as? NSNumber)?.doubleValue ?? Double(width))
            let size = MAAdFormat.banner.adaptiveSize(forWidth: adaptiveWidth)
            viewSize = CGSize(width: adaptiveWidth, height: size.height > 0 ? size.height : CGFloat(height))
        } else {
            viewSize = adSize
        }
        dropBidProbability = debugDropBidProbability(args["debugDropBidProbability"])

        methodChannel = viewChannel(
            "prebid_mobile_sdk_max/banner", args: args, viewId: viewId, messenger: messenger
        )

        // 1. Create and configure the MAX ad view.
        // MAAdView defaults to the banner format; an MREC ad unit needs the
        // MREC format or MAX rejects it.
        maxAdBannerView = MAAdView(
            adUnitIdentifier: maxAdUnitId,
            adFormat: isMrec ? .mrec : .banner
        )
        if adaptive {
            maxAdBannerView.setExtraParameterForKey("adaptive_banner", value: "true")
        }
        maxAdBannerView.frame = CGRect(origin: .zero, size: viewSize)
        maxAdBannerView.isHidden = false

        super.init()

        maxAdBannerView.delegate = self
        maxAdBannerView.revenueDelegate = self

        // 2. Prebid mediation utils + ad unit.
        let mediationDelegate = MAXMediationBannerUtils(adView: maxAdBannerView)
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
        // Prebid iOS has no pbAdSlot setter on this ad unit: send it in the imp.
        if let config = impOrtb(args["impOrtbConfig"] as? String, pbAdSlot: args["pbAdSlot"] as? String) {
            adUnit.setImpORTBConfig(config)
        }
        if let config = args["globalOrtbConfig"] as? String { adUnit.setGlobalORTBConfig(config) }
        if let formats = adFormatsFrom(args["adFormats"]) { adUnit.adFormats = formats }
        // `videoParameters` is a live, get-only reference: configured in place.
        applyVideoParameters(args["videoParameters"], to: adUnit.videoParameters)
        if !additionalSizes.isEmpty { adUnit.additionalSizes = additionalSizes }
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
                self?.maxAdBannerView.stopAutoRefresh()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        if autoLoad {
            load()
        }
    }

    /// 3. Fetch demand, then load the MAX banner. The weak capture skips the
    /// load when the view was disposed meanwhile.
    private func load() {
        mediationAdUnit?.fetchDemand { [weak self] _ in
            guard let self = self else { return }
            if shouldDropBid(self.dropBidProbability) {
                self.maxAdBannerView.setLocalExtraParameterForKey(PBMMediationAdUnitBidKey, value: nil)
            }
            self.maxAdBannerView.loadAd()
        }
    }

    // iOS platform views have no dispose callback: stop answering
    // PrebidBannerAdController calls and refreshing once the view is gone.
    deinit {
        methodChannel.setMethodCallHandler(nil)
        mediationAdUnit?.stopRefresh()
        maxAdBannerView.stopAutoRefresh()
    }

    func view() -> UIView {
        return maxAdBannerView
    }

    // MARK: - MAAdViewAdDelegate

    func didLoad(_ ad: MAAd) {
        send(
            "onAdSize",
            arguments: [
                "width": Double(viewSize.width),
                "height": Double(viewSize.height),
            ])
        send("onAdLoaded", arguments: nil)
        send("onAdDisplayed", arguments: nil)
    }

    func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        let nsError = NSError(
            domain: "MAX",
            code: error.code.rawValue,
            userInfo: [NSLocalizedDescriptionKey: error.message]
        )
        mediationAdUnit?.adObjectDidFailToLoadAd(adObject: maxAdBannerView, with: nsError)
        send("onAdFailed", arguments: failure(PrebidErrorFormatter.describe(error)))
    }

    func didFail(toDisplay ad: MAAd, withError error: MAError) {
        // Dart reports it through onAdFailed too.
        send("onAdDisplayFailed", arguments: failure(PrebidErrorFormatter.describe(error)))
    }

    func didClick(_ ad: MAAd) {
        send("onAdClicked", arguments: nil)
    }

    func didHide(_ ad: MAAd) {
        send("onAdClosed", arguments: nil)
    }

    // MAX reports revenue when the impression is recorded.
    func didPayRevenue(for ad: MAAd) {
        send("onAdImpression", arguments: nil)
        send("onAdRevenuePaid", arguments: revenuePayload(ad))
    }

    func didExpand(_ ad: MAAd) {
        send("onAdExpanded", arguments: nil)
    }

    func didCollapse(_ ad: MAAd) {
        send("onAdCollapsed", arguments: nil)
    }

    func didDisplay(_ ad: MAAd) {}

    /// Calls the widget on the main thread.
    private func send(_ method: String, arguments: Any?) {
        onMain { [methodChannel] in methodChannel.invokeMethod(method, arguments: arguments) }
    }
}
