import Flutter
import UIKit
import PrebidMobile
import PrebidMobileMAXAdapters
import AppLovinSDK

/// PlatformView factory for AppLovin MAX-mediated native ads. The rendered view
/// is a `MANativeAdView` with tag-bound asset views that the MAX SDK populates;
/// Prebid's `MediationNativeAdUnit` runs the auction via the Prebid native
/// adapter. Rendering through the SDK's native view keeps tracking intact.
class MaxNativeAdViewFactory: NSObject, FlutterPlatformViewFactory {

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
        return MaxNativePlatformView(
            viewId: viewId,
            messenger: messenger,
            args: args as? [String: Any] ?? [:]
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class MaxNativePlatformView: NSObject, FlutterPlatformView, MANativeAdDelegate {

    private let container = UIView()
    private let methodChannel: FlutterMethodChannel

    private var nativeAdLoader: MANativeAdLoader?
    private var mediationDelegate: MAXMediationNativeUtils?
    private var adUnit: MediationNativeAdUnit?
    private weak var loadedNativeAd: MAAd?

    init(viewId: Int64, messenger: FlutterBinaryMessenger, args: [String: Any]) {
        let configId = args["configId"] as? String ?? ""
        let maxAdUnitId = args["maxAdUnitId"] as? String ?? ""

        methodChannel = FlutterMethodChannel(
            name: "prebid_mobile_sdk_max/native_\(viewId)",
            binaryMessenger: messenger
        )

        super.init()

        // 1. MAX native ad loader + Prebid mediation utils + ad unit.
        let loader = MANativeAdLoader(adUnitIdentifier: maxAdUnitId)
        loader.nativeAdDelegate = self
        nativeAdLoader = loader

        let mediationDelegate = MAXMediationNativeUtils(nativeAdLoader: loader)
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

        let adView = buildNativeAdView()

        adUnit.fetchDemand { [weak self] _ in
            self?.nativeAdLoader?.loadAd(into: adView)
        }
    }

    func view() -> UIView {
        return container
    }

    /// Builds a `MANativeAdView` with tagged asset subviews and binds them.
    private func buildNativeAdView() -> MANativeAdView {
        let iconView = UIImageView()
        iconView.tag = 1
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.tag = 2
        titleLabel.font = .boldSystemFont(ofSize: 15)

        let advertiserLabel = UILabel()
        advertiserLabel.tag = 4
        advertiserLabel.font = .systemFont(ofSize: 11)
        advertiserLabel.textColor = .gray

        let bodyLabel = UILabel()
        bodyLabel.tag = 3
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.numberOfLines = 3
        bodyLabel.textColor = .gray

        let ctaButton = UIButton(type: .system)
        ctaButton.tag = 5
        ctaButton.titleLabel?.font = .boldSystemFont(ofSize: 14)

        let mediaView = UIView()
        mediaView.tag = 123

        let titles = UIStackView(arrangedSubviews: [titleLabel, advertiserLabel])
        titles.axis = .vertical
        let header = UIStackView(arrangedSubviews: [iconView, titles])
        header.axis = .horizontal
        header.spacing = 8
        header.alignment = .center
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
        ])

        let stack = UIStackView(arrangedSubviews: [header, bodyLabel, mediaView, ctaButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        let adView = MANativeAdView()
        adView.addSubview(iconView)
        adView.addSubview(titleLabel)
        adView.addSubview(advertiserLabel)
        adView.addSubview(bodyLabel)
        adView.addSubview(ctaButton)
        adView.addSubview(mediaView)
        adView.addSubview(stack)
        adView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(adView)
        NSLayoutConstraint.activate([
            adView.topAnchor.constraint(equalTo: container.topAnchor),
            adView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            adView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.topAnchor.constraint(equalTo: adView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
        ])

        let binder = MANativeAdViewBinder(builderBlock: { builder in
            builder.iconImageViewTag = 1
            builder.titleLabelTag = 2
            builder.bodyLabelTag = 3
            builder.advertiserLabelTag = 4
            builder.callToActionButtonTag = 5
            builder.mediaContentViewTag = 123
        })
        adView.bindViews(with: binder)
        return adView
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

    // MARK: - MANativeAdDelegate

    func didLoadNativeAd(_ nativeAdView: MANativeAdView?, for ad: MAAd) {
        if let previous = loadedNativeAd {
            nativeAdLoader?.destroy(previous)
        }
        loadedNativeAd = ad
        methodChannel.invokeMethod("onAdLoaded", arguments: nil)
        let height = container.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        ).height
        if height > 0 {
            methodChannel.invokeMethod("onAdSize", arguments: ["height": Double(height)])
        }
    }

    func didFailToLoadNativeAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        methodChannel.invokeMethod("onAdFailed", arguments: error.message)
    }

    func didClickNativeAd(_ ad: MAAd) {
        methodChannel.invokeMethod("onAdClicked", arguments: nil)
    }
}
