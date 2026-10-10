import PrebidMobile
import UIKit

// Conversions between Pigeon types and the Prebid SDK.

// MARK: - Fullscreen controls

extension FullscreenControlsConfig {
    var minSizePercentage: CGSize? {
        guard let w = minWidthPercentage, let h = minHeightPercentage else { return nil }
        return CGSize(width: Int(w), height: Int(h))
    }

    func apply(to adUnit: InterstitialRenderingAdUnit) {
        if let v = closeButtonArea { adUnit.closeButtonArea = v }
        if let v = closeButtonPosition.flatMap(prebidPosition) { adUnit.closeButtonPosition = v }
        if let v = skipButtonArea { adUnit.skipButtonArea = v }
        if let v = skipButtonPosition.flatMap(prebidPosition) { adUnit.skipButtonPosition = v }
        if let v = skipDelay { adUnit.skipDelay = Double(v) }
        if let v = isMuted { adUnit.isMuted = v }
        if let v = isSoundButtonVisible { adUnit.isSoundButtonVisible = v }
        if let v = isAutoCloseOnCompletionEnabled { adUnit.isAutoCloseOnCompletionEnabled = v }
        if let v = supportSKOverlay { adUnit.supportSKOverlay = v }
    }

    // Prebid iOS rewarded has no skip-button or auto-close controls.
    func apply(to adUnit: RewardedAdUnit) {
        if let v = closeButtonArea { adUnit.closeButtonArea = v }
        if let v = closeButtonPosition.flatMap(prebidPosition) { adUnit.closeButtonPosition = v }
        if let v = isMuted { adUnit.isMuted = v }
        if let v = isSoundButtonVisible { adUnit.isSoundButtonVisible = v }
        if let v = supportSKOverlay { adUnit.supportSKOverlay = v }
    }
}

// MARK: - Video parameters

/// Applies a `VideoParameters.toMap()` payload (banner creation params).
func applyVideoParameters(_ raw: [String: Any], to vp: VideoParameters) {
    func ints(_ key: String) -> [Int]? { (raw[key] as? [Any])?.compactMap { ($0 as? NSNumber)?.intValue } }
    func int(_ key: String) -> Int? { (raw[key] as? NSNumber)?.intValue }
    if let v = raw["mimes"] as? [String] { vp.mimes = v }
    if let v = ints("protocols") { vp.protocols = v.map { Signals.Protocols(integerLiteral: $0) } }
    if let v = ints("playbackMethods") { vp.playbackMethod = v.map { Signals.PlaybackMethod(integerLiteral: $0) } }
    if let v = int("placement") { vp.placement = Signals.Placement(integerLiteral: v) }
    if let v = int("plcmt") { vp.plcmnt = Signals.Plcmnt(integerLiteral: v) }
    if let v = ints("api") { vp.api = v.map { Signals.Api(integerLiteral: $0) } }
    if let v = int("maxDuration") { vp.maxDuration = SingleContainerInt(integerLiteral: v) }
    if let v = int("minDuration") { vp.minDuration = SingleContainerInt(integerLiteral: v) }
    if let v = int("startDelay") { vp.startDelay = Signals.StartDelay(integerLiteral: v) }
    if let v = int("linearity") { vp.linearity = SingleContainerInt(integerLiteral: v) }
    if let v = raw["skippable"] as? Bool { vp.isSkippable = v }
    if let v = ints("battr") { vp.battr = v.map { Signals.CreativeAttribute(integerLiteral: $0) } }
    if let v = int("minBitrate") { vp.minBitrate = SingleContainerInt(integerLiteral: v) }
    if let v = int("maxBitrate") { vp.maxBitrate = SingleContainerInt(integerLiteral: v) }
    if let w = int("width"), let h = int("height") { vp.adSize = CGSize(width: w, height: h) }
}

extension VideoParametersConfig {
    func makeVideoParameters() -> VideoParameters {
        let parameters = VideoParameters(mimes: mimes)
        apply(to: parameters)
        return parameters
    }

    func apply(to vp: VideoParameters) {
        vp.mimes = mimes
        if let v = protocols { vp.protocols = v.compactMap { $0 }.map { Signals.Protocols(integerLiteral: Int($0)) } }
        if let v = playbackMethods {
            vp.playbackMethod = v.compactMap { $0 }.map { Signals.PlaybackMethod(integerLiteral: Int($0)) }
        }
        if let v = placement { vp.placement = Signals.Placement(integerLiteral: Int(v)) }
        if let v = plcmt { vp.plcmnt = Signals.Plcmnt(integerLiteral: Int(v)) }
        if let v = api { vp.api = v.compactMap { $0 }.map { Signals.Api(integerLiteral: Int($0)) } }
        if let v = maxDuration { vp.maxDuration = SingleContainerInt(integerLiteral: Int(v)) }
        if let v = minDuration { vp.minDuration = SingleContainerInt(integerLiteral: Int(v)) }
        if let v = startDelay { vp.startDelay = Signals.StartDelay(integerLiteral: Int(v)) }
        if let v = linearity { vp.linearity = SingleContainerInt(integerLiteral: Int(v)) }
        if let v = skippable { vp.isSkippable = v }
        if let v = battr { vp.battr = v.compactMap { $0 }.map { Signals.CreativeAttribute(integerLiteral: Int($0)) } }
        if let v = minBitrate { vp.minBitrate = SingleContainerInt(integerLiteral: Int(v)) }
        if let v = maxBitrate { vp.maxBitrate = SingleContainerInt(integerLiteral: Int(v)) }
        if let w = width, let h = height { vp.adSize = CGSize(width: Int(w), height: Int(h)) }
    }
}

private func prebidPosition(_ name: String) -> Position? {
    switch name {
    case "topLeft": return .topLeft
    case "topRight": return .topRight
    default: return nil
    }
}

/// The ad formats named by Dart ("banner", "video"); nil for none.
func adFormatSet(_ names: [String]?) -> Set<AdFormat>? {
    let formats = Set(
        (names ?? []).compactMap { name -> AdFormat? in
            switch name {
            case "banner": return .banner
            case "video": return .video
            default: return nil
            }
        })
    return formats.isEmpty ? nil : formats
}

// MARK: - Native

/// Impression-level ORTB JSON with `ext.data.pbadslot` set to [pbAdSlot]
/// (unless the JSON already sets one), for units without a pbAdSlot setter.
func impOrtb(_ json: String?, pbAdSlot: String?) -> String? {
    guard let pbAdSlot = pbAdSlot else { return json }
    var imp = jsonObject(json) ?? [:]
    var ext = imp["ext"] as? [String: Any] ?? [:]
    var data = ext["data"] as? [String: Any] ?? [:]
    if data["pbadslot"] == nil { data["pbadslot"] = pbAdSlot }
    ext["data"] = data
    imp["ext"] = ext
    return (try? JSONSerialization.data(withJSONObject: imp)).flatMap { String(data: $0, encoding: .utf8) } ?? json
}

/// A JSON object string from Dart as a dictionary; nil when invalid.
func jsonObject(_ json: String?) -> [String: Any]? {
    json.flatMap { $0.data(using: .utf8) }
        .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
}

extension NativeAssetConfig {
    /// The Prebid asset for the request; nil for an unknown type. Prebid iOS
    /// has no asset-level `ext`, so `assetExt` is dropped.
    func makePrebidAsset() -> NativeAsset? {
        let ext = jsonObject(self.ext) as AnyObject?
        switch assetType {
        case "title":
            let title = NativeAssetTitle(length: titleLength.map { Int($0) } ?? 90, required: required_)
            title.ext = ext
            return title
        case "image":
            let image = NativeAssetImage(isRequired: required_)
            if let v = imageType { image.type = ImageAsset(integerLiteral: Int(v)) }
            if let v = imageWidth { image.width = Int(v) }
            if let v = imageHeight { image.height = Int(v) }
            if let v = imageWidthMin { image.widthMin = Int(v) }
            if let v = imageHeightMin { image.heightMin = Int(v) }
            if let v = imageMimes { image.mimes = v.compactMap { $0 } }
            image.ext = ext
            return image
        case "data":
            guard let type = dataType.flatMap({ DataAsset(rawValue: Int($0)) }) else { return nil }
            let data = NativeAssetData(type: type, required: required_)
            if let v = dataLength { data.length = Int(v) }
            data.ext = ext
            return data
        default:
            return nil
        }
    }
}

extension NativeEventTrackerConfig {
    /// The Prebid tracker; `ext` is dropped (Prebid iOS doesn't send it).
    func makePrebidTracker() -> NativeEventTracker {
        NativeEventTracker(
            event: EventType(integerLiteral: Int(eventType)),
            methods: methods.map { EventTracking(integerLiteral: Int($0)) }
        )
    }
}

/// The native request settings of a [NativeAdRequestConfig], applied to an
/// In-App `NativeRequest` or an Original API `NativeParameters` (two Prebid
/// types with the same properties and no common protocol).
struct NativeRequestSettings {
    let config: NativeAdRequestConfig
    let assets: [NativeAsset]
    let trackers: [NativeEventTracker]
    let ext: [String: Any]?

    init(_ config: NativeAdRequestConfig) {
        self.config = config
        assets = (config.assets ?? []).compactMap { $0?.makePrebidAsset() }
        trackers = (config.eventTrackers ?? []).compactMap { $0?.makePrebidTracker() }
        ext = jsonObject(config.ext)
    }

    func apply(to request: NativeRequest) {
        if !assets.isEmpty { request.assets = assets }
        if !trackers.isEmpty { request.eventtrackers = trackers }
        if let v = config.context { request.context = ContextType(integerLiteral: Int(v)) }
        if let v = config.contextSubType { request.contextSubType = ContextSubType(integerLiteral: Int(v)) }
        if let v = config.placementType { request.placementType = PlacementType(integerLiteral: Int(v)) }
        if let v = config.placementCount { request.placementCount = Int(v) }
        if let v = config.sequence { request.sequence = Int(v) }
        if let v = config.assetUrlSupport { request.asseturlsupport = v ? 1 : 0 }
        if let v = config.dUrlSupport { request.durlsupport = v ? 1 : 0 }
        if let v = config.privacy { request.privacy = v ? 1 : 0 }
        if let ext = ext { request.ext = ext }
        if let v = config.pbAdSlot { request.pbAdSlot = v }
        if let v = config.gpid { request.setGPID(v) }
        if let v = config.impOrtbConfig { request.setImpORTBConfig(v) }
        if let v = config.globalOrtbConfig { request.setGlobalOrtbConfig(v) }  // AdUnit spells it Ortb.
    }

    func makeParameters() -> NativeParameters {
        let parameters = NativeParameters()
        parameters.assets = assets
        if !trackers.isEmpty { parameters.eventtrackers = trackers }
        if let v = config.context { parameters.context = ContextType(integerLiteral: Int(v)) }
        if let v = config.contextSubType { parameters.contextSubType = ContextSubType(integerLiteral: Int(v)) }
        if let v = config.placementType { parameters.placementType = PlacementType(integerLiteral: Int(v)) }
        if let v = config.placementCount { parameters.placementCount = Int(v) }
        if let v = config.sequence { parameters.sequence = Int(v) }
        if let v = config.assetUrlSupport { parameters.asseturlsupport = v ? 1 : 0 }
        if let v = config.dUrlSupport { parameters.durlsupport = v ? 1 : 0 }
        if let v = config.privacy { parameters.privacy = v ? 1 : 0 }
        if let ext = ext { parameters.ext = ext }
        return parameters
    }
}

extension NativeAd {
    /// The assets of a loaded native ad, as sent to Dart.
    var nativeAdData: NativeAdData {
        NativeAdData(
            title: title,
            text: text,
            iconUrl: iconUrl,
            imageUrl: imageUrl,
            sponsoredBy: sponsoredBy,
            callToAction: callToAction,
            clickUrl: clickURL,
            privacyUrl: privacyUrl,
            titles: titles.map { $0.text },
            images: images.compactMap { image in
                image.type.map {
                    NativeAdImageData(
                        type: Int64($0),
                        url: image.url,
                        width: image.width.map(Int64.init),
                        height: image.height.map(Int64.init)
                    )
                }
            },
            dataAssets: dataObjects.compactMap { data in
                data.type.map { NativeAdDataAssetData(type: Int64($0), value: data.value) }
            }
        )
    }
}

extension BidInfo {
    /// The Original API result of a fetchDemand.
    var multiformatResult: MultiformatBidResult {
        MultiformatBidResult(
            resultCode: resultCode.dartCode,
            events: events.isEmpty ? nil : events.reduce(into: [String?: String?]()) { $0[$1.key] = $1.value },
            exp: exp,
            topBidFiltered: topBidFiltered,
            winningFormat: targetingKeywords?["hb_format"],
            targetingKeywords: targetingKeywords?.reduce(into: [String?: String?]()) { $0[$1.key] = $1.value },
            nativeAdCacheId: nativeAdCacheId
        )
    }
}
