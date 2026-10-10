package io.github.thanhhaidev.prebid_mobile_sdk_admob

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

/**
 * Handles AdMob-mediated rewarded ads over the
 * `prebid_mobile_sdk_admob/rewarded` method channel. Each ad is keyed by an
 * `adId` allocated on the Dart side; native events (including the reward) are
 * pushed back over the same channel.
 */
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
                // Reloading an adId replaces (and frees) its previous ad.
                release(adId)
                val configId = args.get("configId") as? String ?: ""
                val adMobAdUnitId = args.get("adMobAdUnitId") as? String ?: ""

                val dropBidProbability = debugDropBidProbability(args.get("debugDropBidProbability"))
                val extras = Bundle()
                val request = AdRequest.Builder()
                    .addNetworkExtrasBundle(PrebidRewardedAdapter::class.java, extras)
                    .build()

                val mediationUtils = AdMobMediationRewardedUtils(extras)
                val adUnit = MediationRewardedVideoAdUnit(activity, configId, mediationUtils)
                (args.get("impOrtbConfig") as? String)?.let { adUnit.setImpOrtbConfig(it) }
                FullscreenControls.from(args.get("controls"))?.applyTo(adUnit)
                videoMaxDurationFrom(args.get("videoParameters"))?.let { adUnit.setMaxVideoDuration(it) }
                val holder = Holder(adUnit)
                ads[adId] = holder

                adUnit.fetchDemand {
                    // Destroyed / replaced while the auction ran: skip the load.
                    if (ads[adId] !== holder) return@fetchDemand
                    maybeDropBid(dropBidProbability, extras, PrebidRewardedAdapter.EXTRA_RESPONSE_ID)
                    RewardedAd.load(
                        activity,
                        adMobAdUnitId,
                        request,
                        object : RewardedAdLoadCallback() {
                            override fun onAdLoaded(ad: RewardedAd) {
                                if (ads[adId] !== holder) return
                                holder.rewarded = ad
                                ad.fullScreenContentCallback = fullScreenCallback(adId)
                                send(adId, "onAdLoaded")
                            }

                            override fun onAdFailedToLoad(error: LoadAdError) {
                                if (ads[adId] !== holder) return
                                holder.rewarded = null
                                send(adId, "onAdFailed", error.message)
                            }
                        },
                    )
                }
                result.success(null)
            }

            "show" -> {
                if (adId == null) {
                    result.error("no_ad_id", "Missing adId", null)
                    return
                }
                val activity = activityProvider()
                val ad = ads[adId]?.rewarded
                when {
                    ad == null ->
                        send(adId, "onAdFailed", "The rewarded ad is not ready to show; wait for onAdLoaded")
                    activity == null ->
                        send(adId, "onAdFailed", "No attached Activity to show the rewarded ad")
                    else -> {
                        ad.show(activity) { rewardItem ->
                            // Same reward keys as the GAM / MAX packages.
                            val payload = mutableMapOf<String, Any?>(
                                "adId" to adId,
                                "rewardType" to rewardItem.type,
                                "rewardCount" to rewardItem.amount,
                            )
                            channel.invokeMethod("onUserEarnedReward", payload)
                        }
                    }
                }
                result.success(null)
            }

            "destroy" -> {
                adId?.let { release(it) }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Frees the ad for [adId]; its callbacks are detached so a late event
     * cannot be reported against a newer ad with the same id.
     */
    private fun release(adId: Long) {
        ads.remove(adId)?.let {
            it.rewarded?.fullScreenContentCallback = null
            it.rewarded = null
            it.adUnit.destroy()
        }
    }

    private fun fullScreenCallback(adId: Long) = object : FullScreenContentCallback() {
        override fun onAdShowedFullScreenContent() = send(adId, "onAdDisplayed")
        override fun onAdDismissedFullScreenContent() = send(adId, "onAdClosed")
        override fun onAdClicked() = send(adId, "onAdClicked")
        override fun onAdImpression() = send(adId, "onAdImpression")
        override fun onAdFailedToShowFullScreenContent(error: AdError) =
            send(adId, "onAdFailed", error.message)
    }

    private fun send(adId: Long, event: String, error: String? = null) {
        val payload = mutableMapOf<String, Any?>("adId" to adId)
        if (error != null) payload["error"] = error
        channel.invokeMethod(event, payload)
    }
}
