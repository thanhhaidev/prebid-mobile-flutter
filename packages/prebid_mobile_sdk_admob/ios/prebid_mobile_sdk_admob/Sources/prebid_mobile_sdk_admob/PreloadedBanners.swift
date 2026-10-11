import Flutter
import UIKit

// Shared by the companion packages; tool/check_copies.sh keeps the copies
// identical.

/// A companion's preloaded banners (ADR-0008), created and destroyed from
/// Dart on `channelName`. Each is the package's own banner view, built by
/// `create` from the creation params a banner widget sends (`channelId`
/// included) but never handed to Flutter: it is kept until Dart destroys it
/// (releasing it runs its cleanup), and shown by whichever platform view
/// created with `preloaded: true` shows it last.
final class PreloadedBanners {
    private var banners: [Int64: FlutterPlatformView] = [:]
    private let channel: FlutterMethodChannel

    init(
        messenger: FlutterBinaryMessenger,
        channelName: String,
        create: @escaping (Int64, [String: Any]) -> FlutterPlatformView
    ) {
        channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return result(nil) }
            let args = call.arguments as? [String: Any]
            let channelId = (args?["channelId"] as? NSNumber)?.int64Value
            switch call.method {
            case "create":
                if let channelId, self.banners[channelId] == nil {
                    self.banners[channelId] = create(channelId, args?["config"] as? [String: Any] ?? [:])
                }
                result(nil)
            case "destroy":
                if let channelId { self.destroy(channelId) }
                result(nil)
            // After a Dart hot restart: the previous isolate's banners.
            case "releaseAll":
                self.releaseAll()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    /// The platform view showing the banner of `channelId`, if it exists.
    func platformView(frame: CGRect, channelId: Int64) -> FlutterPlatformView {
        return PreloadedBannerPlatformView(frame: frame, banner: banners[channelId]?.view())
    }

    /// Stops listening and destroys every banner (engine detached).
    func dispose() {
        channel.setMethodCallHandler(nil)
        releaseAll()
    }

    private func destroy(_ channelId: Int64) {
        banners.removeValue(forKey: channelId)?.view().removeFromSuperview()
    }

    private func releaseAll() {
        for channelId in Array(banners.keys) { destroy(channelId) }
    }
}

/// Shows a preloaded banner's view in its own container. Releasing it takes
/// the banner out only if it is still there: a newer view may have taken it
/// over.
private final class PreloadedBannerPlatformView: NSObject, FlutterPlatformView {
    private let container: UIView
    private weak var banner: UIView?

    init(frame: CGRect, banner: UIView?) {
        container = BannerContainer(frame: frame)
        self.banner = banner
        super.init()
        if let banner {
            // addSubview takes it out of the view that showed it before.
            banner.frame.origin = .zero
            container.addSubview(banner)
        }
    }

    deinit {
        if let banner, banner.superview === container {
            banner.removeFromSuperview()
        }
    }

    func view() -> UIView {
        return container
    }
}

/// Sizes its banner to its own bounds once it has some, as Flutter sizes a
/// platform view's own view: never to zero, which makes an ad view fail and
/// reload.
private final class BannerContainer: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty else { return }
        for subview in subviews { subview.frame = bounds }
    }
}
