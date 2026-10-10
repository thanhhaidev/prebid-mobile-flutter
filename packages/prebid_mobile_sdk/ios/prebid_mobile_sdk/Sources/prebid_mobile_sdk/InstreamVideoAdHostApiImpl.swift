import Flutter
import PrebidMobile

/// InstreamVideoAdHostApi: Original API in-stream video demand.
final class InstreamVideoAdHostApiImpl: InstreamVideoAdHostApi {

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
        if let v = config.gpid { adUnit.setGPID(v) }
        if let v = config.pbAdSlot { adUnit.pbAdSlot = v }
        if let v = config.impOrtbConfig { adUnit.setImpORTBConfig(v) }
        if let v = config.globalOrtbConfig { adUnit.setGlobalOrtbConfig(v) } // AdUnit spells it Ortb.
        adUnits[adId] = adUnit

        let unitId = ObjectIdentifier(adUnit)
        InFlightAdUnits.retain(adUnit)
        adUnit.fetchDemand(completionBidInfo: { bidInfo in
            InFlightAdUnits.release(unitId)
            var result = bidInfo.multiformatResult
            result.winningFormat = "video"
            completion(.success(result))
        })
    }

    func destroy(adId: Int64) throws {
        adUnits.removeValue(forKey: adId)
    }

    func generateInstreamUriForGam(adUnitId: String, sizes: [Int64], keywords: [String: String]) throws -> String {
        let slotSizes = try stride(from: 0, to: sizes.count - 1, by: 2).map { i -> IMAAdSlotSize in
            switch (sizes[i], sizes[i + 1]) {
            case (400, 300): return .Size400x300
            case (640, 480): return .Size640x480
            case (320, 480): return .Size320x480
            default:
                throw PigeonError(code: "invalidSize",
                                  message: "Prebid iOS supports 400x300, 640x480 and 320x480 only",
                                  details: nil)
            }
        }
        return try IMAUtils.shared.generateInstreamUriForGAM(
            adUnitID: adUnitId, adSlotSizes: slotSizes, customKeywords: keywords)
    }

    func destroyAll() {
        adUnits.removeAll()
    }
}
