package com.prebid.prebid_mobile_sdk_max

import android.app.Activity
import com.applovin.mediation.MaxAd
import com.applovin.mediation.MaxError
import com.applovin.mediation.MaxReward
import com.applovin.mediation.MaxRewardedAdListener
import com.applovin.mediation.adapters.prebid.utils.MaxMediationRewardedUtils
import com.applovin.mediation.ads.MaxRewardedAd
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.prebid.mobile.api.mediation.MediationRewardedVideoAdUnit

/// Handles MAX-mediated rewarded ads over the `prebid_mobile_sdk_max/rewarded`
/// method channel. Each ad is keyed by an `adId` allocated on the Dart side;
/// native events (including the reward) are pushed back over the same channel.
class MaxRewardedManager(
    messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "prebid_mobile_sdk_max/rewarded")

    private class Holder(
        val adUnit: MediationRewardedVideoAdUnit,
        val rewarded: MaxRewardedAd,
    )

    private val ads = mutableMapOf<Long, Holder>()

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        ads.values.forEach {
            it.adUnit.destroy()
            it.rewarded.destroy()
        }
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
                val maxAdUnitId = args?.get("maxAdUnitId") as? String ?: ""

                val rewarded = MaxRewardedAd.getInstance(maxAdUnitId, activity)
                rewarded.setListener(object : MaxRewardedAdListener {
                    override fun onAdLoaded(ad: MaxAd) = send(adId, "onAdLoaded")
                    override fun onAdDisplayed(ad: MaxAd) = send(adId, "onAdDisplayed")
                    override fun onAdHidden(ad: MaxAd) = send(adId, "onAdClosed")
                    override fun onAdClicked(ad: MaxAd) = send(adId, "onAdClicked")
                    override fun onAdLoadFailed(adUnitId: String, error: MaxError) =
                        send(adId, "onAdFailed", error.message)
                    override fun onAdDisplayFailed(ad: MaxAd, error: MaxError) =
                        send(adId, "onAdFailed", error.message)
                    override fun onUserRewarded(ad: MaxAd, reward: MaxReward) {
                        val payload = mutableMapOf<String, Any?>(
                            "adId" to adId,
                            "type" to reward.label,
                            "count" to reward.amount,
                        )
                        channel.invokeMethod("onUserEarnedReward", payload)
                    }
                })

                val mediationUtils = MaxMediationRewardedUtils(rewarded)
                val adUnit = MediationRewardedVideoAdUnit(activity, configId, mediationUtils)
                ads[adId] = Holder(adUnit, rewarded)

                adUnit.fetchDemand {
                    rewarded.loadAd()
                }
                result.success(null)
            }

            "show" -> {
                adId?.let { ads[it]?.rewarded }?.let { ad ->
                    if (ad.isReady) ad.showAd()
                }
                result.success(null)
            }

            "destroy" -> {
                adId?.let { ads.remove(it) }?.let {
                    it.adUnit.destroy()
                    it.rewarded.destroy()
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun send(adId: Long, event: String, error: String? = null) {
        val payload = mutableMapOf<String, Any?>("adId" to adId)
        if (error != null) payload["error"] = error
        channel.invokeMethod(event, payload)
    }
}
