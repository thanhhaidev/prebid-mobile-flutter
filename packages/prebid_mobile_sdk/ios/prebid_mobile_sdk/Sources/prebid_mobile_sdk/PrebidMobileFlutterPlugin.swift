import Flutter
import UIKit
import PrebidMobile

/// Formats Prebid errors, appending `localizedFailureReason` (the real server
/// response) which the SDK hides behind a generic `localizedDescription`.
enum PrebidErrorFormatter {
    static func describe(_ error: Error?) -> String {
        guard let error = error else { return "Unknown error" }
        let nsError = error as NSError
        let description = nsError.localizedDescription
        if let reason = nsError.localizedFailureReason,
           !reason.isEmpty,
           reason != description {
            return "\(description): \(reason)"
        }
        return description
    }
}

/// Finds the view controller to present fullscreen ads from: the top-most
/// presented controller of the foreground key window (scene-aware;
/// `UIApplication.keyWindow` is deprecated and nil in multi-scene apps).
enum PrebidPresenter {
    static func topViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        let window = windows.first { $0.isKeyWindow } ?? windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    static let noViewController = "No view controller to present the ad from"
    static let notReady = "The ad is not loaded"
}

/// Keeps ad units alive while `fetchDemand` runs. Prebid guards its response
/// and timeout handlers with `[weak self]`, so releasing the unit mid-request
/// (destroy, or a new fetch for the same ad) drops the completion and leaves
/// the Dart Future pending. Not captured in the completion itself: the unit
/// stores it (`lastFetchDemandCompletion`), which would be a retain cycle.
enum InFlightAdUnits {
    private static var units: [ObjectIdentifier: AnyObject] = [:]

    static func retain(_ unit: AnyObject) {
        units[ObjectIdentifier(unit)] = unit
    }

    static func release(_ id: ObjectIdentifier) {
        units.removeValue(forKey: id)
    }
}

public class PrebidMobileFlutterPlugin: NSObject, FlutterPlugin,
    PrebidMobileHostApi, TargetingHostApi, InterstitialAdHostApi, NativeAdHostApi {
    
    private var registrar: FlutterPluginRegistrar?
    private var flutterApi: AdFlutterApi?
    private var eventFlutterApi: PrebidEventFlutterApi?
    // Strong reference: Prebid holds its event delegate weakly.
    private var eventDelegate: BidEventForwarder?
    
    private var interstitialAds: [Int64: InterstitialRenderingAdUnit] = [:]
    private var nativeRequests: [Int64: NativeRequest] = [:]
    private var nativeAdResults: [Int64: NativeAd] = [:]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PrebidMobileFlutterPlugin()
        instance.registrar = registrar
        instance.flutterApi = AdFlutterApi(binaryMessenger: registrar.messenger())
        instance.eventFlutterApi = PrebidEventFlutterApi(binaryMessenger: registrar.messenger())
        
        // Register Pigeon APIs
        PrebidMobileHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        TargetingHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        InterstitialAdHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        
        // Register rewarded handler as separate class
        let rewardedHandler = RewardedAdHostApiHandler(flutterApi: instance.flutterApi!)
        RewardedAdHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: rewardedHandler)
        
        NativeAdHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        
        // Register multiformat handler
        let multiformatHandler = MultiformatAdHostApiHandler(
            flutterApi: MultiformatFlutterApi(binaryMessenger: registrar.messenger())
        )
        MultiformatAdHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: multiformatHandler)
        
        // Register in-stream video handler
        let videoHandler = InstreamVideoAdHostApiHandler()
        InstreamVideoAdHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: videoHandler)
        
        // Register banner PlatformView factory
        let bannerFactory = BannerAdViewFactory(messenger: registrar.messenger())
        registrar.register(bannerFactory, withId: "prebid_mobile_flutter/banner_ad")

        // Register native ad PlatformView factory (renders + tracks In-App native)
        let nativeFactory = NativeAdViewFactory(messenger: registrar.messenger(), flutterApi: instance.flutterApi!)
        registrar.register(nativeFactory, withId: "prebid_mobile_flutter/native_ad")
    }
    
    // =========================================================================
    // PrebidMobileHostApi
    // =========================================================================
    
    func initializeSdk(prebidServerUrl: String, accountId: String, nonTrackingUrl: String?,
                       completion: @escaping (Result<InitializationResult, Error>) -> Void) {
        Prebid.shared.prebidServerAccountId = accountId
        let callback: PrebidInitializationCallback = { status, error in
            let statusStr: String
            switch status {
            // Skipped = setDisableStatusCheck(true); Android reports that as
            // SUCCEEDED, so match it.
            case .succeeded, .serverStatusSkipped: statusStr = "succeeded"
            case .serverStatusWarning: statusStr = "serverStatusWarning"
            default: statusStr = "failed"
            }
            completion(.success(InitializationResult(
                status: statusStr,
                error: error?.localizedDescription
            )))
        }
        do {
            if let nonTrackingUrl = nonTrackingUrl {
                // Used instead of serverURL when the user hasn't authorized
                // tracking (ATT).
                try Prebid.initializeSDK(
                    serverURL: prebidServerUrl,
                    nonTrackingURLString: nonTrackingUrl,
                    gadMobileAdsVersion: nil,
                    callback
                )
            } else {
                try Prebid.initializeSDK(serverURL: prebidServerUrl, callback)
            }
        } catch {
            let result = InitializationResult(status: "failed", error: error.localizedDescription)
            completion(.success(result))
        }
    }
    
    func setTimeoutMillis(timeoutMillis: Int64) throws {
        Prebid.shared.timeoutMillis = Int(timeoutMillis)
    }
    
    func setShareGeoLocation(share: Bool) throws {
        Prebid.shared.shareGeoLocation = share
    }
    
    func setPbsDebug(enabled: Bool) throws {
        Prebid.shared.pbsDebug = enabled
    }
    
    func setCustomHeaders(headers: [String: String]) throws {
        Prebid.shared.customHeaders = headers
    }
    
    func setStoredAuctionResponse(response: String) throws {
        Prebid.shared.storedAuctionResponse = response
    }
    
    func clearStoredAuctionResponse() throws {
        // Must be nil, not "" — the SDK serializes an empty string into the request.
        Prebid.shared.storedAuctionResponse = nil
    }
    
    func addStoredBidResponse(bidder: String, responseId: String) throws {
        Prebid.shared.addStoredBidResponse(bidder: bidder, responseId: responseId)
    }
    
    func clearStoredBidResponses() throws {
        Prebid.shared.clearStoredBidResponses()
    }
    
    func setLogLevel(level: Int64) throws {
        switch level {
        case 0: Prebid.shared.logLevel = .debug
        case 1: Prebid.shared.logLevel = .verbose
        case 2: Prebid.shared.logLevel = .info
        case 3: Prebid.shared.logLevel = .warn
        case 4: Prebid.shared.logLevel = .error
        case 5: Prebid.shared.logLevel = .severe
        default: Prebid.shared.logLevel = .info
        }
    }
    
    func setCreativeFactoryTimeout(timeout: Int64) throws {
        Prebid.shared.creativeFactoryTimeout = TimeInterval(timeout) / 1000.0
    }
    
    func setCreativeFactoryTimeoutPreRenderContent(timeout: Int64) throws {
        Prebid.shared.creativeFactoryTimeoutPreRenderContent = TimeInterval(timeout) / 1000.0
    }
    
    func setCustomStatusEndpoint(endpoint: String) throws {
        Prebid.shared.customStatusEndpoint = endpoint
    }

    func setShouldAssignNativeAssetId(assign: Bool) throws {
        Prebid.shared.shouldAssignNativeAssetID = assign
    }

    func setFilterOutUncachedBids(filter: Bool) throws {
        Prebid.shared.filterOutUncachedBids = filter
    }

    func setEidsPlacement(placement: String) throws {
        switch placement {
        case "openRtb26": Prebid.shared.eidsPlacement = .openRTB26
        case "openRtb25": Prebid.shared.eidsPlacement = .openRTB25
        default: Prebid.shared.eidsPlacement = .compatible
        }
    }

    func setIncludeWinners(include: Bool) throws {
        Prebid.shared.includeWinners = include
    }

    func setIncludeBidderKeys(include: Bool) throws {
        Prebid.shared.includeBidderKeys = include
    }
    
    func setAuctionSettingsId(settingsId: String?) throws {
        Prebid.shared.auctionSettingsId = settingsId
    }

    func setDisableStatusCheck(disable: Bool) throws {
        Prebid.shared.shouldDisableStatusCheck = disable
    }

    func setEventDelegateEnabled(enabled: Bool) throws {
        if enabled, let api = eventFlutterApi {
            let forwarder = BidEventForwarder(api: api)
            eventDelegate = forwarder
            Prebid.shared.eventDelegate = forwarder
        } else {
            Prebid.shared.eventDelegate = nil
            eventDelegate = nil
        }
    }

    // SharedID
    func setSendSharedId(send: Bool) throws {
        Targeting.shared.sendSharedId = send
    }

    func getSharedId() throws -> ExternalUserIdData? {
        let id = Targeting.shared.sharedId
        guard let uid = id.uids.first else { return nil }
        return ExternalUserIdData(
            source: id.source,
            identifier: uid.uniqueId,
            atype: uid.aType.int64Value
        )
    }

    func resetSharedId() throws {
        Targeting.shared.resetSharedId()
    }

    // External User IDs
    func setExternalUserIds(userIds: [ExternalUserIdData]) throws {
        let externalIds = userIds.map { data -> ExternalUserId in
            // ext goes on the uid, matching the Android mapping.
            let ext = data.ext?.reduce(into: [String: Any]()) { result, entry in
                if let key = entry.key, let value = entry.value { result[key] = value }
            }
            let uid = UserUniqueID(
                uniqueId: data.identifier,
                aType: NSNumber(value: data.atype ?? 0),
                ext: ext
            )
            let eid = ExternalUserId(source: data.source, uids: [uid])
            eid.inserter = data.inserter
            eid.matcher = data.matcher
            eid.mm = data.mm.map { NSNumber(value: $0) }
            return eid
        }
        Targeting.shared.setExternalUserIds(externalIds)
    }
    
    func getExternalUserIds() throws -> [ExternalUserIdData] {
        guard let ids = Targeting.shared.getExternalUserIds() else { return [] }
        // One entry per uid (like Android), carrying the uid's ext.
        return ids.flatMap { dict -> [ExternalUserIdData] in
            guard let source = dict["source"] as? String,
                  let uids = dict["uids"] as? [[String: Any]] else { return [] }
            return uids.map { uid in
                ExternalUserIdData(
                    source: source,
                    identifier: uid["id"] as? String ?? "",
                    atype: (uid["atype"] as? NSNumber)?.int64Value,
                    ext: (uid["ext"] as? [String: Any])?.reduce(into: [String?: Any?]()) { $0[$1.key] = $1.value }
                )
            }
        }
    }
    
    func clearExternalUserIds() throws {
        Targeting.shared.setExternalUserIds([])
    }
    
    func getSdkVersion() throws -> String {
        return Prebid.shared.version
    }
    
    // =========================================================================
    // TargetingHostApi
    // =========================================================================
    
    func setSubjectToCOPPA(value: Bool?) throws { Targeting.shared.subjectToCOPPA = value }
    func getSubjectToCOPPA() throws -> Bool? { Targeting.shared.subjectToCOPPA }
    
    func setSubjectToGDPR(value: Bool?) throws { Targeting.shared.subjectToGDPR = value }
    func getSubjectToGDPR() throws -> Bool? { Targeting.shared.subjectToGDPR }
    
    func setGDPRConsentString(value: String?) throws { Targeting.shared.gdprConsentString = value }
    func getGDPRConsentString() throws -> String? { Targeting.shared.gdprConsentString }
    
    func setPurposeConsents(value: String?) throws { Targeting.shared.purposeConsents = value }
    func getPurposeConsents() throws -> String? { Targeting.shared.purposeConsents }
    func getPurposeConsent(index: Int64) throws -> Bool? { Targeting.shared.getPurposeConsent(index: Int(index)) }
    func getDeviceAccessConsent() throws -> Bool? { Targeting.shared.getDeviceAccessConsent() }
    
    // US Privacy / CCPA
    func setUSPrivacyString(value: String?) throws {
        if let val_ = value {
            UserDefaults.standard.set(val_, forKey: "IABUSPrivacy_String")
        } else {
            UserDefaults.standard.removeObject(forKey: "IABUSPrivacy_String")
        }
    }
    func getUSPrivacyString() throws -> String? {
        return UserDefaults.standard.string(forKey: "IABUSPrivacy_String")
    }
    
    func addUserKeyword(keyword: String) throws { Targeting.shared.addUserKeyword(keyword) }
    func addUserKeywords(keywords: [String]) throws { Targeting.shared.addUserKeywords(Set(keywords)) }
    func removeUserKeyword(keyword: String) throws { Targeting.shared.removeUserKeyword(keyword) }
    func clearUserKeywords() throws { Targeting.shared.clearUserKeywords() }
    func getUserKeywords() throws -> [String] { Targeting.shared.getUserKeywords() }
    
    func addAppKeyword(keyword: String) throws { Targeting.shared.addAppKeyword(keyword) }
    func addAppKeywords(keywords: [String]) throws { Targeting.shared.addAppKeywords(Set(keywords)) }
    func removeAppKeyword(keyword: String) throws { Targeting.shared.removeAppKeyword(keyword) }
    func clearAppKeywords() throws { Targeting.shared.clearAppKeywords() }
    
    func addAppExtData(key: String, value: String) throws { Targeting.shared.addAppExtData(key: key, value: value) }
    func updateAppExtData(key: String, value: [String]) throws { Targeting.shared.updateAppExtData(key: key, value: Set(value)) }
    func removeAppExtData(key: String) throws { Targeting.shared.removeAppExtData(for: key) }
    func clearAppExtData() throws { Targeting.shared.clearAppExtData() }
    
    // User Ext Data (user.ext.data). Tracked locally and written to
    // Targeting.userExt["data"], which Prebid merges into user.ext — leaving
    // the global ORTB config and any other user.ext keys untouched.
    private static var userExtDataMap: [String: Set<String>] = [:]
    
    func addUserExtData(key: String, value: String) throws {
        PrebidMobileFlutterPlugin.userExtDataMap[key, default: []].insert(value)
        syncUserExtData()
    }
    func updateUserExtData(key: String, value: [String]) throws {
        PrebidMobileFlutterPlugin.userExtDataMap[key] = Set(value)
        syncUserExtData()
    }
    func removeUserExtData(key: String) throws {
        PrebidMobileFlutterPlugin.userExtDataMap.removeValue(forKey: key)
        syncUserExtData()
    }
    func clearUserExtData() throws {
        PrebidMobileFlutterPlugin.userExtDataMap.removeAll()
        syncUserExtData()
    }
    
    private func syncUserExtData() {
        var ext = Targeting.shared.userExt ?? [:]
        let map = PrebidMobileFlutterPlugin.userExtDataMap
        if map.isEmpty {
            ext.removeValue(forKey: "data")
        } else {
            ext["data"] = map.mapValues { Array($0).sorted() } as [String: [String]]
        }
        Targeting.shared.userExt = ext.isEmpty ? nil : ext
    }
    
    func addBidderToAccessControlList(bidderName: String) throws { Targeting.shared.addBidderToAccessControlList(bidderName) }
    func removeBidderFromAccessControlList(bidderName: String) throws { Targeting.shared.removeBidderFromAccessControlList(bidderName) }
    func clearAccessControlList() throws { Targeting.shared.clearAccessControlList() }
    
    func setGlobalOrtbConfig(ortbConfig: String?) throws { Targeting.shared.setGlobalORTBConfig(ortbConfig) }
    func getGlobalOrtbConfig() throws -> String? { Targeting.shared.getGlobalORTBConfig() }
    
    func setContentUrl(url: String?) throws { Targeting.shared.contentUrl = url }
    func setPublisherName(name: String?) throws { Targeting.shared.publisherName = name }
    func setStoreUrl(url: String?) throws { Targeting.shared.storeURL = url }
    func setDomain(domain: String?) throws { Targeting.shared.domain = domain }

    func setSourceApp(sourceApp: String?) throws { Targeting.shared.sourceapp = sourceApp }
    func setItunesId(itunesId: String?) throws { Targeting.shared.itunesID = itunesId }

    func setOmidPartnerName(name: String?) throws { Targeting.shared.omidPartnerName = name }
    func setOmidPartnerVersion(version: String?) throws { Targeting.shared.omidPartnerVersion = version }

    func setUserLatLng(latitude: Double, longitude: Double) throws {
        Targeting.shared.setLatitude(latitude, longitude: longitude)
    }
    func setLocationPrecision(precision: Int64?) throws {
        Targeting.shared.locationPrecision = precision.map { NSNumber(value: $0) }
    }
    
    // =========================================================================
    // InterstitialAdHostApi
    // =========================================================================
    
    func loadAd(adId: Int64, configId: String, adFormats: [String]?, videoConfig: VideoParametersConfig?, impOrtbConfig: String?, controls: FullscreenControlsConfig?) throws {
        let adUnit: InterstitialRenderingAdUnit
        if let minSize = controls?.minSizePercentage {
            adUnit = InterstitialRenderingAdUnit(configID: configId, minSizePercentage: minSize)
        } else {
            adUnit = InterstitialRenderingAdUnit(configID: configId)
        }
        if let impOrtbConfig = impOrtbConfig { adUnit.setImpORTBConfig(impOrtbConfig) }
        controls?.apply(to: adUnit)
        
        if let formats = adFormats {
            var adUnitFormats: Set<AdFormat> = []
            for f in formats {
                if f == "banner" { adUnitFormats.insert(.banner) }
                if f == "video" { adUnitFormats.insert(.video) }
            }
            if !adUnitFormats.isEmpty { adUnit.adFormats = adUnitFormats }
        }
        
        // videoParameters is get-only but returns the ad unit's live
        // (reference-type) parameters, so configure it in place.
        videoConfig?.apply(to: adUnit.videoParameters)
        
        let delegate = InterstitialDelegate(adId: adId, flutterApi: flutterApi!)
        adUnit.delegate = delegate
        objc_setAssociatedObject(adUnit, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        interstitialAds[adId] = adUnit
        adUnit.loadAd()
    }
    
    // show(adId:) satisfies InterstitialAdHostApi
    func show(adId: Int64) throws {
        guard let interstitial = interstitialAds[adId], interstitial.isReady else {
            return sendAdFailed(adId, PrebidPresenter.notReady)
        }
        guard let viewController = PrebidPresenter.topViewController() else {
            return sendAdFailed(adId, PrebidPresenter.noViewController)
        }
        interstitial.show(from: viewController)
    }

    private func sendAdFailed(_ adId: Int64, _ error: String) {
        flutterApi?.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdFailed", error: error)) { _ in }
    }
    
    // destroy(adId:) satisfies InterstitialAdHostApi and NativeAdHostApi  
    func destroy(adId: Int64) throws {
        interstitialAds.removeValue(forKey: adId)
        nativeRequests.removeValue(forKey: adId)
        nativeAdResults.removeValue(forKey: adId)
        NativeAdStore.remove(adId)
    }
    
    // =========================================================================
    // NativeAdHostApi
    // =========================================================================
    
    func loadAd(adId: Int64, config: NativeAdRequestConfig) throws {
        try destroy(adId: adId)
        let nativeRequest = NativeRequest(configId: config.configId)
        
        // Configure context & placement
        if let ctx = config.context {
            nativeRequest.context = ContextType(integerLiteral: Int(ctx))
        }
        if let pt = config.placementType {
            nativeRequest.placementType = PlacementType(integerLiteral: Int(pt))
        }
        if let subtype = config.contextSubType {
            nativeRequest.contextSubType = ContextSubType(integerLiteral: Int(subtype))
        }
        if let pbAdSlot = config.pbAdSlot { nativeRequest.pbAdSlot = pbAdSlot }
        if let gpid = config.gpid { nativeRequest.setGPID(gpid) }
        if let impOrtbConfig = config.impOrtbConfig { nativeRequest.setImpORTBConfig(impOrtbConfig) }
        if let pc = config.placementCount {
            nativeRequest.placementCount = Int(pc)
        }
        
        // Configure assets
        var nativeAssets: [NativeAsset] = []
        if let assets = config.assets {
            for assetConfig in assets {
                guard let ac = assetConfig else { continue }
                switch ac.assetType {
                case "title":
                    let titleAsset = NativeAssetTitle(length: ac.titleLength.map { Int($0) } ?? 90, required: ac.required_)
                    nativeAssets.append(titleAsset)
                case "image":
                    let imgAsset = NativeAssetImage(isRequired: ac.required_)
                    if let imgType = ac.imageType {
                        imgAsset.type = ImageAsset(integerLiteral: Int(imgType))
                    }
                    if let w = ac.imageWidth { imgAsset.width = Int(w) }
                    if let h = ac.imageHeight { imgAsset.height = Int(h) }
                    if let wm = ac.imageWidthMin { imgAsset.widthMin = Int(wm) }
                    if let hm = ac.imageHeightMin { imgAsset.heightMin = Int(hm) }
                    nativeAssets.append(imgAsset)
                case "data":
                    if let dt = ac.dataType, let dataAssetType = DataAsset(rawValue: Int(dt)) {
                        let dataAsset = NativeAssetData(type: dataAssetType, required: ac.required_)
                        if let len = ac.dataLength { dataAsset.length = Int(len) }
                        nativeAssets.append(dataAsset)
                    }
                default:
                    break
                }
            }
        }
        if !nativeAssets.isEmpty {
            nativeRequest.assets = nativeAssets
        }
        
        // Configure event trackers
        if let trackers = config.eventTrackers {
            var nativeTrackers: [NativeEventTracker] = []
            for trackerConfig in trackers {
                guard let tc = trackerConfig else { continue }
                let methods = tc.methods.map { EventTracking(integerLiteral: Int($0)) }
                let eventType = EventType(integerLiteral: Int(tc.eventType))
                nativeTrackers.append(NativeEventTracker(event: eventType, methods: methods))
            }
            if !nativeTrackers.isEmpty {
                nativeRequest.eventtrackers = nativeTrackers
            }
        }
        
        nativeRequests[adId] = nativeRequest
        
        // A destroyed or reloaded ad's result is ignored.
        let requestId = ObjectIdentifier(nativeRequest)
        InFlightAdUnits.retain(nativeRequest)
        nativeRequest.fetchDemand(completionBidInfo: { [weak self] bidInfo in
            InFlightAdUnits.release(requestId)
            guard let self = self,
                  self.nativeRequests[adId].map(ObjectIdentifier.init) == requestId else { return }
            if bidInfo.resultCode == .prebidDemandFetchSuccess {
                // Attempt to find native ad from cache
                guard let cacheId = bidInfo.nativeAdCacheId,
                      let nativeAd = NativeAd.create(cacheId: cacheId) else {
                    self.flutterApi?.onAdEvent(event: AdEvent(
                        adId: adId, eventName: "onAdFailed", error: "Failed to parse native ad"
                    )) { _ in }
                    return
                }
                self.nativeAdResults[adId] = nativeAd
                NativeAdStore.ads[adId] = nativeAd
                let nativeData = NativeAdData(
                    title: nativeAd.title,
                    text: nativeAd.text,
                    iconUrl: nativeAd.iconUrl,
                    imageUrl: nativeAd.imageUrl,
                    sponsoredBy: nativeAd.sponsoredBy,
                    callToAction: nativeAd.callToAction,
                    clickUrl: nativeAd.clickURL,
                    privacyUrl: nativeAd.privacyUrl,
                    titles: nativeAd.titles.map { $0.text },
                    images: nativeAd.images.compactMap { image in
                        image.type.map { NativeAdImageData(type: Int64($0), url: image.url) }
                    },
                    dataAssets: nativeAd.dataObjects.compactMap { data in
                        data.type.map { NativeAdDataAssetData(type: Int64($0), value: data.value) }
                    }
                )
                self.flutterApi?.onAdEvent(event: AdEvent(
                    adId: adId, eventName: "onAdLoaded", nativeAd: nativeData
                )) { _ in }
            } else {
                self.flutterApi?.onAdEvent(event: AdEvent(
                    adId: adId, eventName: "onAdFailed",
                    error: bidInfo.resultCode.dartCode
                )) { _ in }
            }
        })
    }
    
}

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

// MARK: - Bid event forwarder

/// `PrebidEventDelegate` → Flutter. Prebid calls it on a background queue.
private class BidEventForwarder: NSObject, PrebidEventDelegate {
    private let api: PrebidEventFlutterApi

    init(api: PrebidEventFlutterApi) {
        self.api = api
    }

    func prebidBidRequestDidFinish(requestData: Data?, responseData: Data?) {
        let request = requestData.flatMap { String(data: $0, encoding: .utf8) }
        let response = responseData.flatMap { String(data: $0, encoding: .utf8) }
        DispatchQueue.main.async { [api] in
            api.onBidResponse(request: request, response: response) { _ in }
        }
    }
}

// MARK: - Interstitial Delegate
private class InterstitialDelegate: NSObject, InterstitialAdUnitDelegate {
    let adId: Int64
    let flutterApi: AdFlutterApi
    
    init(adId: Int64, flutterApi: AdFlutterApi) {
        self.adId = adId
        self.flutterApi = flutterApi
    }
    
    func interstitialDidReceiveAd(_ interstitial: InterstitialRenderingAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdLoaded")) { _ in }
    }
    
    func interstitial(_ interstitial: InterstitialRenderingAdUnit, didFailToReceiveAdWithError error: Error?) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdFailed", error: PrebidErrorFormatter.describe(error))) { _ in }
    }
    
    func interstitialWillPresentAd(_ interstitial: InterstitialRenderingAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdDisplayed")) { _ in }
    }
    
    func interstitialDidDismissAd(_ interstitial: InterstitialRenderingAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdClosed")) { _ in }
    }
    
    func interstitialDidClickAd(_ interstitial: InterstitialRenderingAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdClicked")) { _ in }
    }

    func interstitialDidExpireAd(_ interstitial: InterstitialRenderingAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdExpired")) { _ in }
    }
}

// MARK: - Rewarded Ad Handler
private class RewardedAdHostApiHandler: RewardedAdHostApi {
    private let flutterApi: AdFlutterApi
    private var rewardedAds: [Int64: RewardedAdUnit] = [:]
    
    init(flutterApi: AdFlutterApi) {
        self.flutterApi = flutterApi
    }
    
    func loadAd(adId: Int64, configId: String, impOrtbConfig: String?, controls: FullscreenControlsConfig?) throws {
        let adUnit = RewardedAdUnit(configID: configId)
        if let impOrtbConfig = impOrtbConfig { adUnit.setImpORTBConfig(impOrtbConfig) }
        controls?.apply(to: adUnit)
        let delegate = RewardedDelegate(adId: adId, flutterApi: flutterApi)
        adUnit.delegate = delegate
        objc_setAssociatedObject(adUnit, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        rewardedAds[adId] = adUnit
        adUnit.loadAd()
    }
    
    func show(adId: Int64) throws {
        guard let rewarded = rewardedAds[adId], rewarded.isReady else {
            return sendAdFailed(adId, PrebidPresenter.notReady)
        }
        guard let viewController = PrebidPresenter.topViewController() else {
            return sendAdFailed(adId, PrebidPresenter.noViewController)
        }
        rewarded.show(from: viewController)
    }

    private func sendAdFailed(_ adId: Int64, _ error: String) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdFailed", error: error)) { _ in }
    }
    
    func destroy(adId: Int64) throws {
        rewardedAds.removeValue(forKey: adId)
    }
}

// MARK: - Rewarded Delegate
private class RewardedDelegate: NSObject, RewardedAdUnitDelegate {
    let adId: Int64
    let flutterApi: AdFlutterApi
    
    init(adId: Int64, flutterApi: AdFlutterApi) {
        self.adId = adId
        self.flutterApi = flutterApi
    }
    
    func rewardedAdDidReceiveAd(_ rewardedAd: RewardedAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdLoaded")) { _ in }
    }
    
    func rewardedAd(_ rewardedAd: RewardedAdUnit, didFailToReceiveAdWithError error: Error?) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdFailed", error: PrebidErrorFormatter.describe(error))) { _ in }
    }
    
    func rewardedAdWillPresentAd(_ rewardedAd: RewardedAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdDisplayed")) { _ in }
    }
    
    func rewardedAdDidDismissAd(_ rewardedAd: RewardedAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdClosed")) { _ in }
    }
    
    func rewardedAdDidClickAd(_ rewardedAd: RewardedAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdClicked")) { _ in }
    }

    func rewardedAdDidExpire(_ rewardedAd: RewardedAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdExpired")) { _ in }
    }
    
    func rewardedAdUserDidEarnReward(_ rewardedAd: RewardedAdUnit, reward: PrebidReward) {
        flutterApi.onAdEvent(event: AdEvent(
            adId: adId,
            eventName: "onUserEarnedReward",
            reward: RewardData(
                type: reward.type ?? "reward",
                count: reward.count?.int64Value ?? 1,
                ext: reward.ext?.reduce(into: [String?: Any?]()) { $0[$1.key] = $1.value }
            )
        )) { _ in }
    }
}

// MARK: - Multiformat Ad Handler
private class MultiformatAdHostApiHandler: MultiformatAdHostApi {
    
    private let flutterApi: MultiformatFlutterApi
    private var adUnits: [Int64: PrebidAdUnit] = [:]
    private var refreshSeconds: [Int64: Int64] = [:]

    init(flutterApi: MultiformatFlutterApi) {
        self.flutterApi = flutterApi
    }
    
    func fetchDemand(
        adId: Int64,
        config: MultiformatAdRequestConfig,
        completion: @escaping (Result<MultiformatBidResult, Error>) -> Void
    ) {
        adUnits[adId]?.stopAutoRefresh()
        let adUnit = PrebidAdUnit(configId: config.configId)
        adUnits[adId] = adUnit
        
        // Build banner parameters
        var bannerParams: BannerParameters?
        if let sizes = config.bannerSizes, !sizes.isEmpty {
            let bp = BannerParameters()
            var adSizes: [CGSize] = []
            let sizeList = sizes.compactMap { $0 }
            var i = 0
            while i + 1 < sizeList.count {
                adSizes.append(CGSize(width: Int(sizeList[i]), height: Int(sizeList[i + 1])))
                i += 2
            }
            bp.adSizes = adSizes
            bannerParams = bp
        }
        
        // Build video parameters
        let videoParams = config.videoConfig?.makeVideoParameters()
        
        // Build native parameters
        var nativeParams: NativeParameters?
        if let nc = config.nativeConfig {
            let np = NativeParameters()
            var assets: [NativeAsset] = []
            if let configAssets = nc.assets {
                for assetConfig in configAssets {
                    guard let ac = assetConfig else { continue }
                    switch ac.assetType {
                    case "title":
                        assets.append(NativeAssetTitle(
                            length: ac.titleLength.map { Int($0) } ?? 90,
                            required: ac.required_
                        ))
                    case "image":
                        let img = NativeAssetImage(isRequired: ac.required_)
                        if let t = ac.imageType { img.type = ImageAsset(integerLiteral: Int(t)) }
                        if let w = ac.imageWidth { img.width = Int(w) }
                        if let h = ac.imageHeight { img.height = Int(h) }
                        if let wm = ac.imageWidthMin { img.widthMin = Int(wm) }
                        if let hm = ac.imageHeightMin { img.heightMin = Int(hm) }
                        assets.append(img)
                    case "data":
                        if let dt = ac.dataType, let dataType = DataAsset(rawValue: Int(dt)) {
                            let data = NativeAssetData(type: dataType, required: ac.required_)
                            if let len = ac.dataLength { data.length = Int(len) }
                            assets.append(data)
                        }
                    default: break
                    }
                }
            }
            np.assets = assets
            if let v = nc.context { np.context = ContextType(integerLiteral: Int(v)) }
            if let v = nc.contextSubType { np.contextSubType = ContextSubType(integerLiteral: Int(v)) }
            if let v = nc.placementType { np.placementType = PlacementType(integerLiteral: Int(v)) }
            
            if let trackers = nc.eventTrackers {
                var nativeTrackers: [NativeEventTracker] = []
                for tc in trackers {
                    guard let tc = tc else { continue }
                    let methods = tc.methods.map { EventTracking(integerLiteral: Int($0)) }
                    let eventType = EventType(integerLiteral: Int(tc.eventType))
                    nativeTrackers.append(NativeEventTracker(event: eventType, methods: methods))
                }
                np.eventtrackers = nativeTrackers
            }
            nativeParams = np
        }
        
        let request = PrebidRequest(
            bannerParameters: bannerParams,
            videoParameters: videoParams,
            nativeParameters: nativeParams,
            isInterstitial: config.isInterstitial,
            isRewarded: config.isRewarded
        )
        if let gpid = config.gpid { request.setGPID(gpid) }
        if let pos = config.adPosition.flatMap({ AdPosition(rawValue: Int($0)) }) {
            request.adPosition = pos
        }
        if let seconds = refreshSeconds[adId] {
            adUnit.setAutoRefreshMillis(time: Double(seconds) * 1000)
        }
        
        let unitId = ObjectIdentifier(adUnit)
        let trackInterstitial = config.trackInterstitialImpression
        // Auto-refresh calls this again for every refreshed auction; the
        // Pigeon reply can be sent once, later results go to Dart as events.
        var replied = false
        InFlightAdUnits.retain(adUnit)
        adUnit.fetchDemand(request: request) { [weak self, weak adUnit] bidInfo in
            InFlightAdUnits.release(unitId)
            let keywords = bidInfo.targetingKeywords?.reduce(into: [String?: String?]()) { $0[$1.key] = $1.value }
            let result = MultiformatBidResult(
                resultCode: bidInfo.resultCode.dartCode,
                exp: bidInfo.exp,
                topBidFiltered: bidInfo.topBidFiltered,
                winningFormat: bidInfo.targetingKeywords?["hb_format"],
                targetingKeywords: keywords,
                nativeAdCacheId: bidInfo.nativeAdCacheId
            )
            if !replied {
                replied = true
                // Prebid's interstitial tracker watches the key window for the
                // ad server's interstitial showing this bid's creative.
                if trackInterstitial, bidInfo.resultCode == .prebidDemandFetchSuccess {
                    adUnit?.activatePrebidInterstitialImpressionTracker()
                }
                completion(.success(result))
            } else if let self = self, let adUnit = adUnit, self.adUnits[adId] === adUnit {
                self.flutterApi.onDemandRefreshed(adId: adId, result: result) { _ in }
            }
        }
    }

    func setAutoRefreshInterval(adId: Int64, seconds: Int64) throws {
        refreshSeconds[adId] = seconds
        adUnits[adId]?.setAutoRefreshMillis(time: Double(seconds) * 1000)
    }

    func stopAutoRefresh(adId: Int64) throws {
        adUnits[adId]?.stopAutoRefresh()
    }

    func resumeAutoRefresh(adId: Int64) throws {
        adUnits[adId]?.resumeAutoRefresh()
    }

    func activateBannerImpressionTracker(adId: Int64) throws -> Bool {
        guard let adUnit = adUnits[adId],
              let root = PrebidPresenter.topViewController()?.view.window else { return false }
        let banners = Self.gmaBannerViews(in: root)
        guard banners.count == 1 else { return false }
        adUnit.activatePrebidAdViewImpressionTracker(adView: banners[0])
        return true
    }

    /// Google Mobile Ads banner views in [view]'s tree, found by class so the
    /// core plugin needn't depend on GMA.
    private static func gmaBannerViews(in view: UIView) -> [UIView] {
        if let type = NSClassFromString("GADBannerView"), view.isKind(of: type) { return [view] }
        return view.subviews.flatMap { gmaBannerViews(in: $0) }
    }
    
    func destroy(adId: Int64) throws {
        refreshSeconds.removeValue(forKey: adId)
        adUnits.removeValue(forKey: adId)?.stopAutoRefresh()
    }
}

// MARK: - In-Stream Video Ad Handler
private class InstreamVideoAdHostApiHandler: InstreamVideoAdHostApi {
    
    private var adUnits: [Int64: InstreamVideoAdUnit] = [:]
    
    func fetchDemand(
        adId: Int64,
        config: InstreamVideoAdRequestConfig,
        completion: @escaping (Result<MultiformatBidResult, Error>) -> Void
    ) {
        let size = CGSize(width: Int(config.width), height: Int(config.height))
        let adUnit = InstreamVideoAdUnit(configId: config.configId, size: size)
        if let videoParameters = config.videoConfig?.makeVideoParameters() {
            adUnit.videoParameters = videoParameters
        }
        adUnits[adId] = adUnit
        
        let unitId = ObjectIdentifier(adUnit)
        InFlightAdUnits.retain(adUnit)
        adUnit.fetchDemand(completionBidInfo: { bidInfo in
            InFlightAdUnits.release(unitId)
            let resultStr = bidInfo.resultCode.dartCode
            
            let keywords = bidInfo.targetingKeywords?.reduce(into: [String?: String?]()) { $0[$1.key] = $1.value }
            
            completion(.success(MultiformatBidResult(
                resultCode: resultStr,
                exp: bidInfo.exp,
                winningFormat: "video",
                targetingKeywords: keywords
            )))
        })
    }
    
    func destroy(adId: Int64) throws {
        adUnits.removeValue(forKey: adId)
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
