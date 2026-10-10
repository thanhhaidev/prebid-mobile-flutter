package io.github.thanhhaidev.prebid_mobile_sdk_gam

import android.app.Activity
import io.flutter.plugin.common.BinaryMessenger
import org.prebid.mobile.api.exceptions.AdException
import org.prebid.mobile.api.rendering.RewardedAdUnit
import org.prebid.mobile.api.rendering.listeners.RewardedAdUnitListener
import org.prebid.mobile.eventhandlers.GamRewardedEventHandler
import org.prebid.mobile.rendering.interstitial.rewarded.Reward

/**
 * GAM-rendered rewarded ads over the `prebid_mobile_sdk_gam/rewarded`
 * method channel.
 */
internal class GamRewardedManager(
    messenger: BinaryMessenger,
    activityProvider: () -> Activity?,
) : FullscreenAdManager<RewardedAdUnit>(
    messenger,
    "prebid_mobile_sdk_gam/rewarded",
    activityProvider,
) {

    override fun create(activity: Activity, adId: Long, args: Map<*, *>): RewardedAdUnit {
        val configId = args["configId"] as? String ?: ""
        val gamAdUnitId = args["gamAdUnitId"] as? String ?: ""
        val eventHandler = GamRewardedEventHandler(activity, gamAdUnitId).apply {
            gamCustomTargeting(args["customTargeting"])?.let { targeting ->
                // Prebid 3.4: app custom targeting on the GAM request; Prebid's
                // hb_* keys still take precedence.
                setAdManagerRequestConfiguration { builder ->
                    targeting.forEach { (k, v) -> builder.addCustomTargeting(k, v) }
                }
            }
        }
        val adUnit = RewardedAdUnit(activity, configId, eventHandler)
        videoMaxDurationFrom(args["videoParameters"])?.let { adUnit.setMaxVideoDuration(it) }
        (args["impOrtbConfig"] as? String)?.let { adUnit.setImpOrtbConfig(it) }
        FullscreenControls.from(args["controls"])?.applyTo(adUnit)
        adUnit.setRewardedAdUnitListener(object : RewardedAdUnitListener {
            override fun onAdLoaded(unit: RewardedAdUnit) = send(adId, "onAdLoaded")
            override fun onAdFailed(unit: RewardedAdUnit, e: AdException?) =
                send(adId, "onAdFailed", e?.message ?: PluginErrors.UNKNOWN)
            override fun onAdDisplayed(unit: RewardedAdUnit) = send(adId, "onAdDisplayed")
            override fun onAdClosed(unit: RewardedAdUnit) = send(adId, "onAdClosed")
            override fun onAdClicked(unit: RewardedAdUnit) = send(adId, "onAdClicked")
            override fun onAdExpired(unit: RewardedAdUnit) = send(adId, "onAdExpired")
            override fun onUserEarnedReward(unit: RewardedAdUnit, reward: Reward?) =
                send(adId, "onUserEarnedReward", extras = rewardPayload(reward))
        })
        return adUnit
    }

    /** The reward keys every companion sends; `rewardExt` only when present. */
    private fun rewardPayload(reward: Reward?): Map<String, Any?> = buildMap {
        put("rewardType", reward?.type ?: "reward")
        put("rewardCount", reward?.count ?: 1)
        reward?.ext?.let { put("rewardExt", it.toString()) }
    }
}
