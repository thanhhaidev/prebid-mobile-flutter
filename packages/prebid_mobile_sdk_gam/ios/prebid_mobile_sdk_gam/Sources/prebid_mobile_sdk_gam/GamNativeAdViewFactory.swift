import Flutter
import UIKit
import GoogleMobileAds

class GamNativeAdViewFactory: NSObject, FlutterPlatformViewFactory {

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

class GamNativePlatformView: NSObject, FlutterPlatformView, NativeAdLoaderDelegate {

    private let nativeAdView = GoogleMobileAds.NativeAdView()
    private let methodChannel: FlutterMethodChannel
    private var adLoader: AdLoader?

    private let iconView = UIImageView()
    private let mediaView = MediaView()
    private let advertiserLabel = UILabel()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let ctaButton = UIButton(type: .system)

    init(messenger: FlutterBinaryMessenger, args: [String: Any]) {
        let logicalId = args["logicalId"] as? Int ?? 0
        let gamAdUnitId = args["gamAdUnitId"] as? String ?? ""
        let customTargeting = args["customTargeting"] as? [String: String] ?? [:]

        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_gam/native_\(logicalId)",
            binaryMessenger: messenger
        )

        super.init()
        buildLayout()

        let request = AdManagerRequest()
        request.customTargeting = customTargeting

        let loader = AdLoader(
            adUnitID: gamAdUnitId,
            rootViewController: UIApplication.shared.keyWindow?.rootViewController,
            adTypes: [.native],
            options: nil
        )
        loader.delegate = self
        adLoader = loader
        loader.load(request)
    }

    func view() -> UIView {
        return nativeAdView
    }

    private func buildLayout() {
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.contentMode = .scaleAspectFill
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFill
        iconView.clipsToBounds = true
        advertiserLabel.font = .systemFont(ofSize: 11)
        advertiserLabel.textColor = .gray
        headlineLabel.font = .boldSystemFont(ofSize: 15)
        headlineLabel.numberOfLines = 2
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.numberOfLines = 3
        bodyLabel.textColor = .gray
        ctaButton.titleLabel?.font = .boldSystemFont(ofSize: 14)
        ctaButton.isUserInteractionEnabled = false

        let titleStack = UIStackView(arrangedSubviews: [advertiserLabel, headlineLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 2

        let header = UIStackView(arrangedSubviews: [iconView, titleStack])
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

        nativeAdView.mediaView = mediaView
        nativeAdView.iconView = iconView
        nativeAdView.advertiserView = advertiserLabel
        nativeAdView.headlineView = headlineLabel
        nativeAdView.bodyView = bodyLabel
        nativeAdView.callToActionView = ctaButton
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: GoogleMobileAds.NativeAd) {
        headlineLabel.text = nativeAd.headline
        advertiserLabel.text = nativeAd.advertiser ?? "Sponsored"
        bodyLabel.text = nativeAd.body
        ctaButton.setTitle(nativeAd.callToAction, for: .normal)
        iconView.image = nativeAd.icon?.image
        mediaView.mediaContent = nativeAd.mediaContent
        nativeAdView.nativeAd = nativeAd
        methodChannel.invokeMethod("onAdLoaded", arguments: nil)
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        methodChannel.invokeMethod("onAdFailed", arguments: error.localizedDescription)
    }
}
