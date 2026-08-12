import Flutter
import UIKit
import GoogleMobileAds
import PrebidMobile
import PrebidMobileAdMobAdapters

/// PlatformView factory for AdMob-mediated native ads. The rendered view is a
/// Google Mobile Ads `NativeAdView` populated with the winning ad's assets;
/// Prebid's `MediationNativeAdUnit` runs the auction via the Prebid native
/// adapter. Rendering through the SDK's native view keeps impression/click
/// tracking intact.
class AdMobNativeAdViewFactory: NSObject, FlutterPlatformViewFactory {

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

class AdMobNativePlatformView: NSObject, FlutterPlatformView, NativeAdLoaderDelegate {

    private let nativeAdView = GoogleMobileAds.NativeAdView()
    private let methodChannel: FlutterMethodChannel

    private let iconView = UIImageView()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let ctaButton = UIButton(type: .system)

    private var adLoader: AdLoader?
    private var mediationDelegate: AdMobMediationNativeUtils?
    private var adUnit: MediationNativeAdUnit?

    init(viewId: Int64, messenger: FlutterBinaryMessenger, args: [String: Any]) {
        let configId = args["configId"] as? String ?? ""
        let adMobAdUnitId = args["adMobAdUnitId"] as? String ?? ""

        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_admob/native_\(viewId)",
            binaryMessenger: messenger
        )

        super.init()

        buildLayout()

        // Prebid mediation native ad unit.
        let request = Request()
        let mediationDelegate = AdMobMediationNativeUtils(gadRequest: request)
        self.mediationDelegate = mediationDelegate
        let adUnit = MediationNativeAdUnit(
            configId: configId,
            mediationDelegate: mediationDelegate
        )
        adUnit.addNativeAssets(Self.requestAssets)
        adUnit.setContextType(.Social)
        adUnit.setPlacementType(.FeedContent)
        adUnit.setContextSubType(.Social)
        adUnit.addEventTracker([
            NativeEventTracker(event: .Impression, methods: [.Image, .js])
        ])
        self.adUnit = adUnit

        adUnit.fetchDemand { [weak self] _ in
            guard let self = self else { return }
            let loader = AdLoader(
                adUnitID: adMobAdUnitId,
                rootViewController: UIApplication.shared.keyWindow?.rootViewController,
                adTypes: [.native],
                options: nil
            )
            loader.delegate = self
            self.adLoader = loader
            loader.load(request)
        }
    }

    func view() -> UIView {
        return nativeAdView
    }

    private func buildLayout() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
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
        ])

        let stack = UIStackView(arrangedSubviews: [header, bodyLabel, ctaButton])
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
        nativeAdView.headlineView = headlineLabel
        nativeAdView.bodyView = bodyLabel
        nativeAdView.callToActionView = ctaButton
    }

    private static var requestAssets: [NativeAsset] {
        let icon = NativeAssetImage(minimumWidth: 20, minimumHeight: 20, required: true)
        icon.type = ImageAsset.Icon
        let title = NativeAssetTitle(length: 90, required: true)
        let body = NativeAssetData(type: DataAsset.description, required: true)
        let cta = NativeAssetData(type: DataAsset.ctatext, required: true)
        let sponsored = NativeAssetData(type: DataAsset.sponsored, required: true)
        return [title, icon, sponsored, body, cta]
    }

    // MARK: - NativeAdLoaderDelegate

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: GoogleMobileAds.NativeAd) {
        headlineLabel.text = nativeAd.headline
        bodyLabel.text = nativeAd.body
        ctaButton.setTitle(nativeAd.callToAction, for: .normal)
        iconView.image = nativeAd.icon?.image
        nativeAdView.nativeAd = nativeAd

        methodChannel.invokeMethod("onAdLoaded", arguments: nil)
        let height = nativeAdView.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        ).height
        if height > 0 {
            methodChannel.invokeMethod("onAdSize", arguments: ["height": Double(height)])
        }
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        methodChannel.invokeMethod("onAdFailed", arguments: error.localizedDescription)
    }
}
