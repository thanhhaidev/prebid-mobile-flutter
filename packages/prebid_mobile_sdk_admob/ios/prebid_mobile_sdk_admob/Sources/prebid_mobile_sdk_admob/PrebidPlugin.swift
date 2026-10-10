import Flutter
import Foundation
import PrebidMobile

// Shared by the companion packages; tool/check_copies.sh keeps the copies
// identical. The request parsing is in PrebidRequests, each package's own
// helpers in PrebidShared.

/// Runs `body` on the main thread: Flutter channels must be called there,
/// and not every SDK callback arrives on it.
func onMain(_ body: @escaping () -> Void) {
    if Thread.isMainThread {
        body()
    } else {
        DispatchQueue.main.async(execute: body)
    }
}

/// The payload of a native view's failure event (`onAdFailed`,
/// `primaryAdFailed`, ...): `{error: message}`, as the fullscreen ads send.
func failure(_ message: String) -> [String: Any] {
    ["error": message]
}

/// The method channel of a platform view: `<prefix>_<channelId>`, the id the
/// Dart widget listens on before the view exists (so a failure reported
/// during creation is not lost). Falls back to the platform view id.
func viewChannel(
    _ prefix: String,
    args: [String: Any],
    viewId: Int64,
    messenger: FlutterBinaryMessenger
) -> FlutterMethodChannel {
    let channelId = (args["channelId"] as? NSNumber)?.int64Value ?? viewId
    return FlutterMethodChannel(name: "\(prefix)_\(channelId)", binaryMessenger: messenger)
}

/// `debugDropBidProbability` (`PrebidAdMob` / `PrebidMax`
/// `.debugDropBidProbability`, testing only), clamped to `0...1`; 0 when
/// absent.
func debugDropBidProbability(_ raw: Any?) -> Double {
    guard let p = (raw as? NSNumber)?.doubleValue, !p.isNaN else { return 0 }
    return min(max(p, 0), 1)
}

/// Testing hook: whether to withhold this load's Prebid bid, with
/// `probability`.
func shouldDropBid(_ probability: Double) -> Bool {
    probability > 0 && Double.random(in: 0..<1) < probability
}

/// `adFormats` (`PrebidAdFormat` names), or `nil` when it names none.
func adFormatsFrom(_ raw: Any?) -> Set<PrebidMobile.AdFormat>? {
    let names = raw as? [String] ?? []
    // Qualified: GoogleMobileAds also has an `AdFormat`.
    var formats = Set<PrebidMobile.AdFormat>()
    if names.contains("banner") { formats.insert(.banner) }
    if names.contains("video") { formats.insert(.video) }
    return formats.isEmpty ? nil : formats
}

/// Interstitial formats: `adFormats` when it names any, else video or banner
/// from `isVideo`.
func adFormatsFrom(_ raw: Any?, isVideo: Bool) -> Set<PrebidMobile.AdFormat> {
    adFormatsFrom(raw) ?? (isVideo ? [.video] : [.banner])
}
