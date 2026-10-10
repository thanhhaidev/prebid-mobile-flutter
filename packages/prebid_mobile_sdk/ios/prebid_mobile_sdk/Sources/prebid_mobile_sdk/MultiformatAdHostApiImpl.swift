import Flutter
import PrebidMobile
import UIKit

/// MultiformatAdHostApi: the Original API (PrebidAdUnit fetchDemand → targeting keywords).
final class MultiformatAdHostApiImpl: MultiformatAdHostApi {

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
        // Prebid iOS ignores intervals under 30 s; clamp like Android.
        let seconds = min(max(seconds, 30), 120)
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

    func destroyAll() {
        adUnits.keys.forEach { try? destroy(adId: $0) }
    }
}
