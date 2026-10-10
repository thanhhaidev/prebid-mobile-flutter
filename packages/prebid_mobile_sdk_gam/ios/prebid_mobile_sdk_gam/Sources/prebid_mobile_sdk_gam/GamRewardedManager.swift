import Flutter
import UIKit
import PrebidMobile
import PrebidMobileGAMEventHandlers

/// GAM-rendered rewarded ads over the `prebid_mobile_sdk_gam/rewarded` method
/// channel.
final class GamRewardedManager: GamFullscreenAdManager {

    init(messenger: FlutterBinaryMessenger) {
        super.init(name: "prebid_mobile_sdk_gam/rewarded", messenger: messenger)
    }

    override func makeAdUnit(_ args: [String: Any], delegate: GamFullscreenEvents) -> GamFullscreenAdUnit {
        let configId = args["configId"] as? String ?? ""
        let gamAdUnitId = args["gamAdUnitId"] as? String ?? ""

        let eventHandler = GAMRewardedAdEventHandler(adUnitID: gamAdUnitId)
        if let targeting = gamCustomTargeting(args["customTargeting"]) {
            // Prebid 3.4: app custom targeting on the GAM request; Prebid's
            // hb_* keys still take precedence.
            eventHandler.adManagerRequestConfiguration = { request in
                var merged = request.customTargeting ?? [:]
                targeting.forEach { merged[$0.key] = $0.value }
                request.customTargeting = merged
            }
        }
        let controls = FullscreenControls(args["controls"])
        let adUnit: RewardedAdUnit
        if let minSize = controls?.minSizePercentage {
            adUnit = RewardedAdUnit(configID: configId, minSizePercentage: minSize, eventHandler: eventHandler)
        } else {
            adUnit = RewardedAdUnit(configID: configId, eventHandler: eventHandler)
        }
        controls?.apply(to: adUnit)
        applyVideoParameters(args["videoParameters"], to: adUnit.videoParameters)
        // Prebid iOS has no pbAdSlot setter on this ad unit: send it in the imp.
        if let config = impOrtb(args["impOrtbConfig"] as? String, pbAdSlot: args["pbAdSlot"] as? String) {
            adUnit.setImpORTBConfig(config)
        }
        if let config = args["globalOrtbConfig"] as? String { adUnit.setGlobalORTBConfig(config) }
        adUnit.delegate = delegate
        return adUnit
    }
}
