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
///
/// MAX hands out one shared [MaxRewardedAd] per ad unit, so at most one `adId`
/// owns a unit at a time: a new load on the same unit takes it over (the
/// previous owner gets `onAdFailed`), and only the owner may destroy it.
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

    /// MAX ad unit id → the `adId` that currently owns its shared instance.
    private val ownerByUnit = mutableMapOf<String, Long>()

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        ads.keys.toList().forEach { release(it) }
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
                // Reloading an adId replaces (and frees) its previous ad.
                release(adId)
                val configId = args?.get("configId") as? String ?: ""
                val maxAdUnitId = args?.get("maxAdUnitId") as? String ?: ""

                // The shared instance moves to this adId; the previous owner
                // stops receiving events (the listener is replaced below) and
                // is told why. Its Prebid ad unit is freed, the MAX ad is not.
                ownerByUnit[maxAdUnitId]?.takeIf { it != adId }?.let { previous ->
                    ads.remove(previous)?.adUnit?.destroy()
                    send(previous, "onAdFailed", "Replaced by another ad on the same MAX ad unit")
                }
                ownerByUnit[maxAdUnitId] = adId

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
                        // Same reward keys as the GAM / AdMob packages.
                        val payload = mutableMapOf<String, Any?>(
                            "adId" to adId,
                            "rewardType" to reward.label,
                            "rewardCount" to reward.amount,
                        )
                        channel.invokeMethod("onUserEarnedReward", payload)
                    }
                })

                // MAX reports revenue when the impression is recorded.
                rewarded.setRevenueListener { send(adId, "onAdImpression") }

                val mediationUtils = MaxMediationRewardedUtils(rewarded)
                val adUnit = MediationRewardedVideoAdUnit(activity, configId, mediationUtils)
                FullscreenControls.from(args?.get("controls"))?.applyTo(adUnit)
                val holder = Holder(adUnit, rewarded)
                ads[adId] = holder

                adUnit.fetchDemand {
                    // Destroyed / replaced while the auction ran: skip the load.
                    if (ads[adId] === holder) rewarded.loadAd()
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
                    ad == null || !ad.isReady ->
                        send(adId, "onAdFailed", "The rewarded ad is not ready to show; wait for onAdLoaded")
                    activity == null ->
                        send(adId, "onAdFailed", "No attached Activity to show the rewarded ad")
                    // Show from the current Activity, not the one used to load.
                    else -> ad.showAd(activity)
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

    /// Frees the ad for [adId]. The shared MAX instance is destroyed only when
    /// [adId] still owns its unit — a replaced ad must not destroy the
    /// instance the new owner is using.
    private fun release(adId: Long) {
        val holder = ads.remove(adId) ?: return
        holder.adUnit.destroy()
        val unitId = holder.rewarded.adUnitId
        if (ownerByUnit[unitId] == adId) {
            ownerByUnit.remove(unitId)
            holder.rewarded.destroy()
        }
    }

    private fun send(adId: Long, event: String, error: String? = null) {
        val payload = mutableMapOf<String, Any?>("adId" to adId)
        if (error != null) payload["error"] = error
        channel.invokeMethod(event, payload)
    }
}
