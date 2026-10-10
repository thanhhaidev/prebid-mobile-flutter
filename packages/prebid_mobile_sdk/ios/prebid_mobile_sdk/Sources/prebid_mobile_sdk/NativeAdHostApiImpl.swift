import Flutter
import PrebidMobile

/// NativeAdHostApi: In-App native ads; the assets go to Dart, which renders
/// them, and the ad is kept in the [NativeAdStore] for the native view.
final class NativeAdHostApiImpl: NativeAdHostApi {
    private let flutterApi: AdFlutterApi
    private let nativeAdStore: NativeAdStore
    private var nativeRequests: [Int64: NativeRequest] = [:]
    private var nativeAdResults: [Int64: NativeAd] = [:]

    init(flutterApi: AdFlutterApi, store: NativeAdStore) {
        self.flutterApi = flutterApi
        self.nativeAdStore = store
    }

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
                    self.flutterApi.onAdEvent(event: AdEvent(
                        adId: adId, eventName: "onAdFailed", error: "Failed to parse native ad"
                    )) { _ in }
                    return
                }
                self.nativeAdResults[adId] = nativeAd
                self.nativeAdStore.put(
                    adId, ad: nativeAd,
                    delegate: NativeAdEventForwarder(adId: adId, flutterApi: self.flutterApi)
                )
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
                self.flutterApi.onAdEvent(event: AdEvent(
                    adId: adId, eventName: "onAdLoaded", nativeAd: nativeData
                )) { _ in }
            } else {
                self.flutterApi.onAdEvent(event: AdEvent(
                    adId: adId, eventName: "onAdFailed",
                    error: bidInfo.resultCode.dartCode
                )) { _ in }
            }
        })
    }


    func destroy(adId: Int64) throws {
        nativeRequests.removeValue(forKey: adId)
        nativeAdResults.removeValue(forKey: adId)
        nativeAdStore.remove(adId)
    }

    func destroyAll() {
        nativeRequests.removeAll()
        nativeAdResults.removeAll()
        nativeAdStore.removeAll()
    }
}
