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
    private let preloaded: PreloadedBanners

    init(messenger: FlutterBinaryMessenger, preloaded: PreloadedBanners) {
        self.messenger = messenger
        self.preloaded = preloaded
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let args = args as? [String: Any] ?? [:]
        if args["preloaded"] as? Bool == true {
            let channelId = (args["channelId"] as? NSNumber)?.int64Value ?? viewId
            return preloaded.platformView(frame: frame, channelId: channelId)
        }
        return MaxBannerPlatformView(
            frame: frame,
            viewId: viewId,
            messenger: messenger,
            args: args
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
    private var makeAdUnit: (() -> (MAXMediationBannerUtils, MediationBannerAdUnit))!
    private var refreshStopped = false

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

        // 2. Prebid mediation utils + ad unit. A load after stopRefresh
        // builds them again: Prebid's unit can't resume once stopped.
        makeAdUnit = { [maxAdBannerView, adSize] in
            let mediationDelegate = MAXMediationBannerUtils(adView: maxAdBannerView)
            let adUnit = MediationBannerAdUnit(
                configID: configId,
                size: adSize,
                mediationDelegate: mediationDelegate
            )
            configureMediationBanner(adUnit, args: args)
            return (mediationDelegate, adUnit)
        }
        installAdUnit()

        // Calls from PrebidBannerAdController.
        methodChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "loadAd":
                self?.load()
                result(nil)
            case "stopRefresh":
                self?.refreshStopped = true
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

    /// A new Prebid mediation unit (and its delegate) from `makeAdUnit`.
    private func installAdUnit() {
        (mediationDelegate, mediationAdUnit) = makeAdUnit()
    }

    /// 3. Fetch demand, then load the MAX banner. The weak capture skips the
    /// load when the view was disposed meanwhile.
    private func load() {
        if refreshStopped {
            refreshStopped = false
            installAdUnit()
        }
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
