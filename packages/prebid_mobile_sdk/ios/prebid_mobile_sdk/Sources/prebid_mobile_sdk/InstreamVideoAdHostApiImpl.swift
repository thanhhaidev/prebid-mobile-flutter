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

    func destroyAll() {
        adUnits.removeAll()
    }
}
