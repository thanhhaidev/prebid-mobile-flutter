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

class BannerAdPlatformView: NSObject, FlutterPlatformView, BannerViewDelegate {
    
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
        
        if isVideo {
            bannerView.adFormat = .video
        }
        
        if let interval = refreshInterval, interval > 0 {
            bannerView.refreshInterval = TimeInterval(interval)
        }
        
        bannerView.delegate = self
        
        if autoLoad {
            bannerView.loadAd()
        }
    }
    
    func view() -> UIView {
        return bannerView
    }
    
    // MARK: - BannerViewDelegate
    
    func bannerViewPresentationController() -> UIViewController? {
        return UIApplication.shared.keyWindow?.rootViewController
    }
    
    func bannerView(_ bannerView: BannerView, didReceiveAdWithAdSize adSize: CGSize) {
        methodChannel.invokeMethod("onAdLoaded", arguments: nil)
    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWith error: Error) {
        methodChannel.invokeMethod("onAdFailed", arguments: error.localizedDescription)
    }
    
    func bannerViewWillPresentModal(_ bannerView: BannerView) {
        methodChannel.invokeMethod("onAdClicked", arguments: nil)
    }
    
    func bannerViewDidDismissModal(_ bannerView: BannerView) {
        methodChannel.invokeMethod("onAdClosed", arguments: nil)
    }
}
