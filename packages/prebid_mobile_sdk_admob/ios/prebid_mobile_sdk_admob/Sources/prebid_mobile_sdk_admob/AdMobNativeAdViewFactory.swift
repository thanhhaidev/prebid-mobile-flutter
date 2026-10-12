import Flutter
import GoogleMobileAds
import PrebidMobile
import PrebidMobileAdMobAdapters
import UIKit

/// PlatformView factory for AdMob-mediated native ads. The rendered view is a
/// Google Mobile Ads `NativeAdView` populated with the winning ad's assets;
/// Prebid's `MediationNativeAdUnit` runs the auction via the Prebid native
/// adapter. Rendering through the SDK's native view keeps impression/click
/// tracking intact.
final class AdMobNativeAdViewFactory: NSObject, FlutterPlatformViewFactory {

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
        return AdMobNativePlatformView(
            viewId: viewId,
            messenger: messenger,
            args: args as? [String: Any] ?? [:]
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// One AdMob native ad: the `NativeAdView` populated with the ad AdMob loads
/// after the Prebid auction, reporting to Dart over
/// `prebid_mobile_sdk_admob/native_<channelId>`.
final class AdMobNativePlatformView: NSObject, FlutterPlatformView, NativeAdLoaderDelegate,
    GoogleMobileAds.NativeAdDelegate
{

    private let container = NativeAdContainer()
    private let nativeAdView = GoogleMobileAds.NativeAdView()
    private let methodChannel: FlutterMethodChannel

    private let iconView = UIImageView()
    private let mediaView = MediaView()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let ctaButton = UIButton(type: .system)

    private var adLoader: AdLoader?
    private var mediationDelegate: AdMobMediationNativeUtils?
    private var adUnit: MediationNativeAdUnit?

    init(viewId: Int64, messenger: FlutterBinaryMessenger, args: [String: Any]) {
        let configId = args["configId"] as? String ?? ""
        let adMobAdUnitId = args["adMobAdUnitId"] as? String ?? ""

        methodChannel = viewChannel(
            "prebid_mobile_sdk_admob/native", args: args, viewId: viewId, messenger: messenger
        )

        super.init()

        buildLayout()
        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nativeAdView)
        NSLayoutConstraint.activate([
            nativeAdView.topAnchor.constraint(equalTo: container.topAnchor),
            nativeAdView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            nativeAdView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            nativeAdView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        container.onHeight = { [weak self] height in self?.send("onAdSize", ["height": Double(height)]) }

        // Prebid mediation native ad unit.
        let request = Request()
        let mediationDelegate = AdMobMediationNativeUtils(gadRequest: request)
        self.mediationDelegate = mediationDelegate
        let adUnit = MediationNativeAdUnit(
            configId: configId,
            mediationDelegate: mediationDelegate
        )
        configureMediationNative(adUnit, args: args)
        self.adUnit = adUnit

        adUnit.fetchDemand { [weak self] _ in
            onMain {
                guard let self = self else { return }
                let loader = AdLoader(
                    adUnitID: adMobAdUnitId,
                    // The view's own window: GMA presents click-throughs from it.
                    rootViewController: PrebidPresenter.topViewController(in: self.container.window),
                    adTypes: [.native],
                    options: nil
                )
                loader.delegate = self
                self.adLoader = loader
                loader.load(request)
            }
        }
    }

    func view() -> UIView {
        return container
    }

    /// Sends `event` to the widget on the main thread.
    private func send(_ event: String, _ arguments: Any? = nil) {
        onMain { [methodChannel] in methodChannel.invokeMethod(event, arguments: arguments) }
    }

    private func buildLayout() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.contentMode = .scaleAspectFill
        headlineLabel.font = .boldSystemFont(ofSize: 15)
        headlineLabel.numberOfLines = 2
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.numberOfLines = 3
        bodyLabel.textColor = .gray
        ctaButton.titleLabel?.font = .boldSystemFont(ofSize: 14)
        ctaButton.isUserInteractionEnabled = false

        let header = UIStackView(arrangedSubviews: [iconView, headlineLabel])
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .center
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

        nativeAdView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
        ])

        // Register asset views with the native ad view so clicks/impressions work.
        nativeAdView.iconView = iconView
        nativeAdView.mediaView = mediaView
        nativeAdView.headlineView = headlineLabel
        nativeAdView.bodyView = bodyLabel
        nativeAdView.callToActionView = ctaButton
    }

    // MARK: - NativeAdLoaderDelegate

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: GoogleMobileAds.NativeAd) {
        headlineLabel.text = nativeAd.headline
        bodyLabel.text = nativeAd.body
        ctaButton.setTitle(nativeAd.callToAction, for: .normal)
        iconView.image = nativeAd.icon?.image
        mediaView.mediaContent = nativeAd.mediaContent
        nativeAd.delegate = self
        nativeAdView.nativeAd = nativeAd

        send("onAdLoaded")
        container.reportHeight()
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        send("onAdFailed", failure(PrebidErrorFormatter.describe(error)))
    }

    // MARK: - GoogleMobileAds.NativeAdDelegate

    func nativeAdDidRecordImpression(_ nativeAd: GoogleMobileAds.NativeAd) {
        send("onAdImpression")
    }

    func nativeAdDidRecordClick(_ nativeAd: GoogleMobileAds.NativeAd) {
        send("onAdClicked")
    }

    func nativeAdWillPresentScreen(_ nativeAd: GoogleMobileAds.NativeAd) {
        send("onAdOpened")
    }
}
