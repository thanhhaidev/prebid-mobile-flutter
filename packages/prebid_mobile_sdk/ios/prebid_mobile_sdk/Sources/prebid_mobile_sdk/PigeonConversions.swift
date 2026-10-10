import PrebidMobile

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

    // Prebid iOS rewarded has no skip-button controls.
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
        if let v = playbackMethods { vp.playbackMethod = v.compactMap { $0 }.map { Signals.PlaybackMethod(integerLiteral: Int($0)) } }
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
    }
}

private func prebidPosition(_ name: String) -> Position? {
    switch name {
    case "topLeft": return .topLeft
    case "topRight": return .topRight
    default: return nil
    }
}

/// The result-code names the Dart API uses (matching the Android mapping), so
/// both platforms report the same strings.
extension ResultCode {
    var dartCode: String {
        switch self {
        case .prebidDemandFetchSuccess: return "prebidDemandFetchSuccess"
        case .prebidServerNotSpecified: return "prebidServerNotSpecified"
        case .prebidInvalidAccountId: return "prebidInvalidAccountId"
        case .prebidInvalidConfigId: return "prebidInvalidConfigId"
        case .prebidInvalidSize: return "prebidInvalidSize"
        case .prebidNetworkError: return "prebidNetworkError"
        case .prebidServerError: return "prebidServerError"
        case .prebidDemandNoBids: return "prebidDemandNoBids"
        case .prebidDemandTimedOut: return "prebidDemandTimedOut"
        case .prebidServerURLInvalid: return "prebidServerURLInvalid"
        case .prebidDemandNoCachedBids: return "prebidDemandNoCachedBids"
        default: return "prebidInvalidRequest"
        }
    }
}
