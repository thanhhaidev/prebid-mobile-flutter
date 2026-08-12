package com.prebid.prebid_mobile_sdk_gam

import android.app.Activity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.prebid.mobile.api.exceptions.AdException
import org.prebid.mobile.api.rendering.RewardedAdUnit
import org.prebid.mobile.api.rendering.listeners.RewardedAdUnitListener
import org.prebid.mobile.eventhandlers.GamRewardedEventHandler
import org.prebid.mobile.rendering.interstitial.rewarded.Reward

class GamRewardedManager(
    messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "prebid_mobile_sdk_gam/rewarded")
    private val ads = mutableMapOf<Long, RewardedAdUnit>()

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        ads.values.forEach { it.destroy() }
        ads.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val adId = (args?.get("adId") as? Number)?.toLong()

        when (call.method) {
            "load" -> {
                val activity = activityProvider()
                if (activity == null) {
                    result.error("no_activity", "No attached Activity to load the rewarded ad", null)
                    return
                }
                if (adId == null) {
                    result.error("no_ad_id", "Missing adId", null)
                    return
                }
                val configId = args?.get("configId") as? String ?: ""
                val gamAdUnitId = args?.get("gamAdUnitId") as? String ?: ""

                val eventHandler = GamRewardedEventHandler(activity, gamAdUnitId)
                val adUnit = RewardedAdUnit(activity, configId, eventHandler)

                adUnit.setRewardedAdUnitListener(object : RewardedAdUnitListener {
                    override fun onAdLoaded(unit: RewardedAdUnit) = send(adId, "onAdLoaded")
                    override fun onAdFailed(unit: RewardedAdUnit, e: AdException?) =
                        send(adId, "onAdFailed", e?.message ?: "Unknown error")
                    override fun onAdDisplayed(unit: RewardedAdUnit) = send(adId, "onAdDisplayed")
                    override fun onAdClosed(unit: RewardedAdUnit) = send(adId, "onAdClosed")
                    override fun onAdClicked(unit: RewardedAdUnit) = send(adId, "onAdClicked")
                    override fun onUserEarnedReward(unit: RewardedAdUnit, reward: Reward?) =
                        send(
                            adId,
                            "onUserEarnedReward",
                            rewardType = reward?.type ?: "reward",
                            rewardCount = reward?.count ?: 1,
                        )
                })

                ads[adId] = adUnit
                adUnit.loadAd()
                result.success(null)
            }

            "show" -> {
                ads[adId]?.show()
                result.success(null)
            }

            "destroy" -> {
                ads.remove(adId)?.destroy()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun send(
        adId: Long,
        event: String,
        error: String? = null,
        rewardType: String? = null,
        rewardCount: Int? = null,
    ) {
        val payload = mutableMapOf<String, Any?>("adId" to adId)
        if (error != null) payload["error"] = error
        if (rewardType != null) payload["rewardType"] = rewardType
        if (rewardCount != null) payload["rewardCount"] = rewardCount
        channel.invokeMethod(event, payload)
    }
}
