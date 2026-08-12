package com.prebid.prebid_mobile_sdk_admob

import android.app.Activity
import android.os.Bundle
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.prebid.mobile.admob.AdMobMediationRewardedUtils
import org.prebid.mobile.admob.PrebidRewardedAdapter
import org.prebid.mobile.api.mediation.MediationRewardedVideoAdUnit

/// Handles AdMob-mediated rewarded ads over the
/// `prebid_mobile_sdk_admob/rewarded` method channel. Each ad is keyed by an
/// `adId` allocated on the Dart side; native events (including the reward) are
/// pushed back over the same channel.
class AdMobRewardedManager(
    messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "prebid_mobile_sdk_admob/rewarded")

    private class Holder(val adUnit: MediationRewardedVideoAdUnit) {
        var rewarded: RewardedAd? = null
    }

    private val ads = mutableMapOf<Long, Holder>()

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        ads.values.forEach { it.adUnit.destroy() }
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
                val adMobAdUnitId = args?.get("adMobAdUnitId") as? String ?: ""

                val extras = Bundle()
                val request = AdRequest.Builder()
                    .addNetworkExtrasBundle(PrebidRewardedAdapter::class.java, extras)
                    .build()

                val mediationUtils = AdMobMediationRewardedUtils(extras)
                val adUnit = MediationRewardedVideoAdUnit(activity, configId, mediationUtils)
                val holder = Holder(adUnit)
                ads[adId] = holder

                adUnit.fetchDemand {
                    RewardedAd.load(
                        activity,
                        adMobAdUnitId,
                        request,
                        object : RewardedAdLoadCallback() {
                            override fun onAdLoaded(ad: RewardedAd) {
                                holder.rewarded = ad
                                ad.fullScreenContentCallback = fullScreenCallback(adId)
                                send(adId, "onAdLoaded")
                            }

                            override fun onAdFailedToLoad(error: LoadAdError) {
                                holder.rewarded = null
                                send(adId, "onAdFailed", error.message)
                            }
                        },
                    )
                }
                result.success(null)
            }

            "show" -> {
                val activity = activityProvider()
                val ad = adId?.let { ads[it]?.rewarded }
                if (ad != null && activity != null) {
                    ad.show(activity) { rewardItem ->
                        val payload = mutableMapOf<String, Any?>(
                            "adId" to adId,
                            "type" to rewardItem.type,
                            "count" to rewardItem.amount,
                        )
                        channel.invokeMethod("onUserEarnedReward", payload)
                    }
                }
                result.success(null)
            }

            "destroy" -> {
                adId?.let { ads.remove(it)?.adUnit?.destroy() }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun fullScreenCallback(adId: Long) = object : FullScreenContentCallback() {
        override fun onAdShowedFullScreenContent() = send(adId, "onAdDisplayed")
        override fun onAdDismissedFullScreenContent() = send(adId, "onAdClosed")
        override fun onAdClicked() = send(adId, "onAdClicked")
        override fun onAdFailedToShowFullScreenContent(error: AdError) =
            send(adId, "onAdFailed", error.message)
    }

    private fun send(adId: Long, event: String, error: String? = null) {
        val payload = mutableMapOf<String, Any?>("adId" to adId)
        if (error != null) payload["error"] = error
        channel.invokeMethod(event, payload)
    }
}
