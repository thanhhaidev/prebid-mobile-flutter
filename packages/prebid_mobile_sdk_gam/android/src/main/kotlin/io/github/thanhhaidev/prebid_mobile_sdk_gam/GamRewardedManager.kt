package io.github.thanhhaidev.prebid_mobile_sdk_gam

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
                if (adId == null) {
                    result.error("no_ad_id", "Missing adId", null)
                    return
                }
                val activity = activityProvider()
                if (activity == null) {
                    // Reported through the listener, as iOS does and as `show`
                    // does, rather than as a PlatformException from loadAd().
                    send(adId, "onAdFailed", "No attached Activity to load the rewarded ad")
                    result.success(null)
                    return
                }
                // Reloading an adId replaces (and frees) its previous ad unit.
                ads.remove(adId)?.destroy()
                val configId = args.get("configId") as? String ?: ""
                val gamAdUnitId = args.get("gamAdUnitId") as? String ?: ""

                val eventHandler = GamRewardedEventHandler(activity, gamAdUnitId).apply {
                    gamCustomTargeting(args.get("customTargeting"))?.let { targeting ->
                        // Prebid 3.4: app custom targeting on the GAM request; Prebid's
                        // hb_* keys still take precedence.
                        setAdManagerRequestConfiguration { builder ->
                            targeting.forEach { (k, v) -> builder.addCustomTargeting(k, v) }
                        }
                    }
                }
                val adUnit = RewardedAdUnit(activity, configId, eventHandler)
                videoMaxDurationFrom(args.get("videoParameters"))?.let { adUnit.setMaxVideoDuration(it) }
                (args.get("impOrtbConfig") as? String)?.let { adUnit.setImpOrtbConfig(it) }
                FullscreenControls.from(args.get("controls"))?.applyTo(adUnit)

                adUnit.setRewardedAdUnitListener(object : RewardedAdUnitListener {
                    override fun onAdLoaded(unit: RewardedAdUnit) = send(adId, "onAdLoaded")
                    override fun onAdFailed(unit: RewardedAdUnit, e: AdException?) =
                        send(adId, "onAdFailed", e?.message ?: "Unknown error")
                    override fun onAdDisplayed(unit: RewardedAdUnit) = send(adId, "onAdDisplayed")
                    override fun onAdClosed(unit: RewardedAdUnit) = send(adId, "onAdClosed")
                    override fun onAdClicked(unit: RewardedAdUnit) = send(adId, "onAdClicked")
                    override fun onAdExpired(unit: RewardedAdUnit) = send(adId, "onAdExpired")
                    override fun onUserEarnedReward(unit: RewardedAdUnit, reward: Reward?) =
                        send(
                            adId,
                            "onUserEarnedReward",
                            rewardType = reward?.type ?: "reward",
                            rewardCount = reward?.count ?: 1,
                            rewardExt = reward?.ext?.toString(),
                        )
                })

                ads[adId] = adUnit
                adUnit.loadAd()
                result.success(null)
            }

            "show" -> {
                if (adId == null) {
                    result.error("no_ad_id", "Missing adId", null)
                    return
                }
                val adUnit = ads[adId]
                when {
                    adUnit == null || !adUnit.isLoaded ->
                        send(adId, "onAdFailed", "The rewarded ad is not ready to show; wait for onAdLoaded")
                    // Prebid shows from the Activity the ad unit was loaded with.
                    activityProvider() == null ->
                        send(adId, "onAdFailed", "No attached Activity to show the rewarded ad")
                    else -> adUnit.show()
                }
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
        rewardExt: String? = null,
    ) {
        val payload = mutableMapOf<String, Any?>("adId" to adId)
        if (error != null) payload["error"] = error
        if (rewardType != null) payload["rewardType"] = rewardType
        if (rewardCount != null) payload["rewardCount"] = rewardCount
        if (rewardExt != null) payload["rewardExt"] = rewardExt
        channel.invokeMethod(event, payload)
    }
}
