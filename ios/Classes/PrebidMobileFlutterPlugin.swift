import Flutter
import UIKit
import PrebidMobile

public class PrebidMobileFlutterPlugin: NSObject, FlutterPlugin,
    PrebidMobileHostApi, TargetingHostApi, InterstitialAdHostApi, NativeAdHostApi {
    
    private var registrar: FlutterPluginRegistrar?
    private var flutterApi: AdFlutterApi?
    
    private var interstitialAds: [Int64: InterstitialRenderingAdUnit] = [:]
    private var nativeRequests: [Int64: NativeRequest] = [:]
    private var nativeAdResults: [Int64: NativeAd] = [:]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PrebidMobileFlutterPlugin()
        instance.registrar = registrar
        instance.flutterApi = AdFlutterApi(binaryMessenger: registrar.messenger())
        
        // Register Pigeon APIs
        PrebidMobileHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        TargetingHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        InterstitialAdHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        
        // Register rewarded handler as separate class
        let rewardedHandler = RewardedAdHostApiHandler(flutterApi: instance.flutterApi!)
        RewardedAdHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: rewardedHandler)
        
        NativeAdHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        
        // Register multiformat handler
        let multiformatHandler = MultiformatAdHostApiHandler()
        MultiformatAdHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: multiformatHandler)
        
        // Register in-stream video handler
        let videoHandler = InstreamVideoAdHostApiHandler()
        InstreamVideoAdHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: videoHandler)
        
        // Register banner PlatformView factory
        let bannerFactory = BannerAdViewFactory(messenger: registrar.messenger())
        registrar.register(bannerFactory, withId: "prebid_mobile_flutter/banner_ad")
    }
    
    // =========================================================================
    // PrebidMobileHostApi
    // =========================================================================
    
    func initializeSdk(prebidServerUrl: String, accountId: String,
                       completion: @escaping (Result<InitializationResult, Error>) -> Void) {
        Prebid.shared.prebidServerAccountId = accountId
        do {
            try Prebid.initializeSDK(serverURL: prebidServerUrl) { status, error in
                let statusStr: String
                switch status {
                case .succeeded: statusStr = "succeeded"
                case .serverStatusWarning: statusStr = "serverStatusWarning"
                default: statusStr = "failed"
                }
                let result = InitializationResult(
                    status: statusStr,
                    error: error?.localizedDescription
                )
                completion(.success(result))
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
        Prebid.shared.storedAuctionResponse = ""
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
    
    // External User IDs
    func setExternalUserIds(userIds: [ExternalUserIdData]) throws {
        var externalIds: [ExternalUserId] = []
        for data in userIds {
            let uid = ExternalUserId(source: data.source, identifier: data.identifier)
            if let atype = data.atype {
                uid.atype = NSNumber(value: atype)
            }
            externalIds.append(uid)
        }
        Targeting.shared.externalUserIds = externalIds
    }
    
    func getExternalUserIds() throws -> [ExternalUserIdData] {
        let ids = Targeting.shared.externalUserIds
        return ids.map { uid in
            ExternalUserIdData(
                source: uid.source,
                identifier: uid.identifier,
                atype: uid.atype?.int64Value
            )
        }
    }
    
    func clearExternalUserIds() throws {
        Targeting.shared.externalUserIds = []
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
    
    // User Ext Data
    func addUserExtData(key: String, value: String) throws { Targeting.shared.addUserData(key: key, value: value) }
    func updateUserExtData(key: String, value: [String]) throws { Targeting.shared.updateUserData(key: key, value: Set(value)) }
    func removeUserExtData(key: String) throws { Targeting.shared.removeUserData(for: key) }
    func clearUserExtData() throws { Targeting.shared.clearUserData() }
    
    func addBidderToAccessControlList(bidderName: String) throws { Targeting.shared.addBidderToAccessControlList(bidderName) }
    func removeBidderFromAccessControlList(bidderName: String) throws { Targeting.shared.removeBidderFromAccessControlList(bidderName) }
    func clearAccessControlList() throws { Targeting.shared.clearAccessControlList() }
    
    func setGlobalOrtbConfig(ortbConfig: String?) throws { Targeting.shared.setGlobalORTBConfig(ortbConfig) }
    func getGlobalOrtbConfig() throws -> String? { Targeting.shared.getGlobalORTBConfig() }
    
    func setContentUrl(url: String?) throws { Targeting.shared.contentUrl = url }
    func setPublisherName(name: String?) throws { Targeting.shared.publisherName = name }
    func setStoreUrl(url: String?) throws { Targeting.shared.storeURL = url }
    func setDomain(domain: String?) throws { Targeting.shared.domain = domain }
    
    // =========================================================================
    // InterstitialAdHostApi
    // =========================================================================
    
    func loadAd(adId: Int64, configId: String, adFormats: [String]?, videoConfig: VideoParametersConfig?) throws {
        let adUnit = InterstitialRenderingAdUnit(configID: configId)
        
        if let formats = adFormats {
            var adUnitFormats: Set<AdFormat> = []
            for f in formats {
                if f == "banner" { adUnitFormats.insert(.banner) }
                if f == "video" { adUnitFormats.insert(.video) }
            }
            if !adUnitFormats.isEmpty { adUnit.adFormats = adUnitFormats }
        }
        
        // Apply video parameters if provided
        if let vc = videoConfig {
            let vp = VideoParameters(mimes: vc.mimes)
            if let protocols = vc.protocols {
                vp.protocols = protocols.compactMap { $0 }.map { Signals.Protocols(integerLiteral: Int($0)) }
            }
            if let methods = vc.playbackMethods {
                vp.playbackMethod = methods.compactMap { $0 }.map { Signals.PlaybackMethod(integerLiteral: Int($0)) }
            }
            if let placement = vc.placement {
                vp.placement = Signals.Placement(integerLiteral: Int(placement))
            }
            if let maxDur = vc.maxDuration { vp.maxDuration = SingleContainerInt(integerLiteral: Int(maxDur)) }
            if let minDur = vc.minDuration { vp.minDuration = SingleContainerInt(integerLiteral: Int(minDur)) }
            adUnit.videoParameters = vp
        }
        
        let delegate = InterstitialDelegate(adId: adId, flutterApi: flutterApi!)
        adUnit.delegate = delegate
        objc_setAssociatedObject(adUnit, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        interstitialAds[adId] = adUnit
        adUnit.loadAd()
    }
    
    // show(adId:) satisfies InterstitialAdHostApi
    func show(adId: Int64) throws {
        guard let rootVC = UIApplication.shared.keyWindow?.rootViewController else { return }
        if let interstitial = interstitialAds[adId] {
            interstitial.show(from: rootVC)
        }
    }
    
    // destroy(adId:) satisfies InterstitialAdHostApi and NativeAdHostApi  
    func destroy(adId: Int64) throws {
        interstitialAds.removeValue(forKey: adId)
        nativeRequests.removeValue(forKey: adId)
        nativeAdResults.removeValue(forKey: adId)
    }
    
    // =========================================================================
    // NativeAdHostApi
    // =========================================================================
    
    func loadAd(adId: Int64, config: NativeAdRequestConfig) throws {
        let nativeRequest = NativeRequest(configId: config.configId)
        
        // Configure context & placement
        if let ctx = config.context {
            nativeRequest.context = ContextType(integerLiteral: Int(ctx))
        }
        if let pt = config.placementType {
            nativeRequest.placementType = PlacementType(integerLiteral: Int(pt))
        }
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
        
        nativeRequest.fetchDemand(completionBidInfo: { [weak self] bidInfo in
            guard let self = self else { return }
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
                let nativeData = NativeAdData(
                    title: nativeAd.title,
                    text: nativeAd.text,
                    iconUrl: nativeAd.iconUrl,
                    imageUrl: nativeAd.imageUrl,
                    sponsoredBy: nativeAd.sponsoredBy,
                    callToAction: nativeAd.callToAction,
                    clickUrl: nativeAd.clickURL
                )
                self.flutterApi?.onAdEvent(event: AdEvent(
                    adId: adId, eventName: "onAdLoaded", nativeAd: nativeData
                )) { _ in }
            } else {
                self.flutterApi?.onAdEvent(event: AdEvent(
                    adId: adId, eventName: "onAdFailed",
                    error: "Demand fetch failed: \(bidInfo.resultCode)"
                )) { _ in }
            }
        })
    }
    
    func trackImpression(adId: Int64) throws {
        // Impression tracking is handled automatically by the native SDK
    }
    
    func trackClick(adId: Int64) throws {
        // Click tracking is handled automatically by the native SDK
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
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdFailed", error: error?.localizedDescription)) { _ in }
    }
    
    func interstitialWillPresentAd(_ interstitial: InterstitialRenderingAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdDisplayed")) { _ in }
    }
    
    func interstitialDidDismissAd(_ interstitial: InterstitialRenderingAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdDismissed")) { _ in }
    }
    
    func interstitialDidClickAd(_ interstitial: InterstitialRenderingAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdClicked")) { _ in }
    }
}

// MARK: - Rewarded Ad Handler
private class RewardedAdHostApiHandler: RewardedAdHostApi {
    private let flutterApi: AdFlutterApi
    private var rewardedAds: [Int64: RewardedAdUnit] = [:]
    
    init(flutterApi: AdFlutterApi) {
        self.flutterApi = flutterApi
    }
    
    func loadAd(adId: Int64, configId: String) throws {
        let adUnit = RewardedAdUnit(configID: configId)
        let delegate = RewardedDelegate(adId: adId, flutterApi: flutterApi)
        adUnit.delegate = delegate
        objc_setAssociatedObject(adUnit, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        rewardedAds[adId] = adUnit
        adUnit.loadAd()
    }
    
    func show(adId: Int64) throws {
        guard let rootVC = UIApplication.shared.keyWindow?.rootViewController else { return }
        rewardedAds[adId]?.show(from: rootVC)
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
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdFailed", error: error?.localizedDescription)) { _ in }
    }
    
    func rewardedAdWillPresentAd(_ rewardedAd: RewardedAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdDisplayed")) { _ in }
    }
    
    func rewardedAdDidDismissAd(_ rewardedAd: RewardedAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdDismissed")) { _ in }
    }
    
    func rewardedAdDidClickAd(_ rewardedAd: RewardedAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(adId: adId, eventName: "onAdClicked")) { _ in }
    }
    
    func rewardedAdUserDidEarnReward(_ rewardedAd: RewardedAdUnit) {
        flutterApi.onAdEvent(event: AdEvent(
            adId: adId,
            eventName: "onUserEarnedReward",
            reward: RewardData(type: "reward", count: 1)
        )) { _ in }
    }
}

// MARK: - Multiformat Ad Handler
private class MultiformatAdHostApiHandler: MultiformatAdHostApi {
    
    private var adUnits: [Int64: PrebidAdUnit] = [:]
    
    func fetchDemand(
        adId: Int64,
        config: MultiformatAdRequestConfig,
        completion: @escaping (Result<MultiformatBidResult, Error>) -> Void
    ) {
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
        var videoParams: VideoParameters?
        if let vc = config.videoConfig {
            let vp = VideoParameters(mimes: vc.mimes)
            if let protocols = vc.protocols {
                vp.protocols = protocols.compactMap { $0 }.map { Signals.Protocols(integerLiteral: Int($0)) }
            }
            if let methods = vc.playbackMethods {
                vp.playbackMethod = methods.compactMap { $0 }.map { Signals.PlaybackMethod(integerLiteral: Int($0)) }
            }
            if let placement = vc.placement {
                vp.placement = Signals.Placement(integerLiteral: Int(placement))
            }
            if let maxDur = vc.maxDuration { vp.maxDuration = SingleContainerInt(integerLiteral: Int(maxDur)) }
            if let minDur = vc.minDuration { vp.minDuration = SingleContainerInt(integerLiteral: Int(minDur)) }
            videoParams = vp
        }
        
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
        
        adUnit.fetchDemand(request: request) { [weak self] bidInfo in
            let resultStr: String
            switch bidInfo.resultCode {
            case .prebidDemandFetchSuccess: resultStr = "prebidDemandFetchSuccess"
            case .prebidDemandNoBids: resultStr = "prebidDemandNoBids"
            case .prebidDemandTimedOut: resultStr = "prebidDemandTimedOut"
            default: resultStr = "\(bidInfo.resultCode)"
            }
            
            let format = bidInfo.targetingKeywords?["hb_format"]
            let keywords = bidInfo.targetingKeywords?.reduce(into: [String?: String?]()) { $0[$1.key] = $1.value }
            
            completion(.success(MultiformatBidResult(
                resultCode: resultStr,
                winningFormat: format,
                targetingKeywords: keywords,
                nativeAdCacheId: bidInfo.nativeAdCacheId
            )))
        }
    }
    
    func destroy(adId: Int64) throws {
        adUnits.removeValue(forKey: adId)
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
        adUnits[adId] = adUnit
        
        adUnit.fetchDemand(completionBidInfo: { [weak self] bidInfo in
            let resultStr: String
            switch bidInfo.resultCode {
            case .prebidDemandFetchSuccess: resultStr = "prebidDemandFetchSuccess"
            case .prebidDemandNoBids: resultStr = "prebidDemandNoBids"
            case .prebidDemandTimedOut: resultStr = "prebidDemandTimedOut"
            default: resultStr = "\(bidInfo.resultCode)"
            }
            
            let keywords = bidInfo.targetingKeywords?.reduce(into: [String?: String?]()) { $0[$1.key] = $1.value }
            
            completion(.success(MultiformatBidResult(
                resultCode: resultStr,
                winningFormat: "video",
                targetingKeywords: keywords
            )))
        })
    }
    
    func destroy(adId: Int64) throws {
        adUnits.removeValue(forKey: adId)
    }
}
