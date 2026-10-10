package com.prebid.prebid_mobile_sdk_max

import android.app.Activity
import com.applovin.mediation.MaxAd
import com.applovin.mediation.MaxAdListener
import com.applovin.mediation.MaxError
import com.applovin.mediation.adapters.PrebidMaxMediationAdapter
import com.applovin.mediation.adapters.prebid.utils.MaxMediationInterstitialUtils
import com.applovin.mediation.ads.MaxInterstitialAd
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.prebid.mobile.api.mediation.MediationInterstitialAdUnit

/// Handles MAX-mediated interstitials over the
/// `prebid_mobile_sdk_max/interstitial` method channel. Each ad is keyed by an
/// `adId` allocated on the Dart side; native events are pushed back over the
/// same channel.
class MaxInterstitialManager(
    messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "prebid_mobile_sdk_max/interstitial")

    private class Holder(
        val adUnit: MediationInterstitialAdUnit,
        val interstitial: MaxInterstitialAd,
    )

    private val ads = mutableMapOf<Long, Holder>()

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        ads.values.forEach {
            it.adUnit.destroy()
            it.interstitial.destroy()
        }
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
                    send(adId, "onAdFailed", "No attached Activity to load the interstitial")
                    result.success(null)
                    return
                }
                // Reloading an adId replaces (and frees) its previous ad.
                release(adId)
                val configId = args.get("configId") as? String ?: ""
                val maxAdUnitId = args.get("maxAdUnitId") as? String ?: ""
                val isVideo = args.get("isVideo") as? Boolean ?: false
                val dropBidProbability = debugDropBidProbability(args.get("debugDropBidProbability"))

                val interstitial = MaxInterstitialAd(maxAdUnitId, activity)
                interstitial.setListener(object : MaxAdListener {
                    override fun onAdLoaded(ad: MaxAd) = send(adId, "onAdLoaded")
                    override fun onAdLoadFailed(adUnitId: String, error: MaxError) =
                        send(adId, "onAdFailed", error.message)
                    override fun onAdDisplayed(ad: MaxAd) = send(adId, "onAdDisplayed")
                    override fun onAdDisplayFailed(ad: MaxAd, error: MaxError) =
                        send(adId, "onAdFailed", error.message)
                    override fun onAdHidden(ad: MaxAd) = send(adId, "onAdClosed")
                    override fun onAdClicked(ad: MaxAd) = send(adId, "onAdClicked")
                })

                // MAX reports revenue when the impression is recorded.
                interstitial.setRevenueListener { ad ->
                    send(adId, "onAdImpression")
                    channel.invokeMethod("onAdRevenuePaid", revenuePayload(ad) + ("adId" to adId))
                }

                val mediationUtils = MaxMediationInterstitialUtils(interstitial)
                val adUnit = MediationInterstitialAdUnit(
                    activity,
                    configId,
                    adUnitFormats(args.get("adFormats"), isVideo),
                    mediationUtils,
                )
                (args.get("impOrtbConfig") as? String)?.let { adUnit.setImpOrtbConfig(it) }
                FullscreenControls.from(args.get("controls"))?.applyTo(adUnit)
                videoMaxDurationFrom(args.get("videoParameters"))?.let { adUnit.setMaxVideoDuration(it) }
                val holder = Holder(adUnit, interstitial)
                ads[adId] = holder

                adUnit.fetchDemand {
                    // Destroyed / replaced while the auction ran: skip the load.
                    if (ads[adId] !== holder) return@fetchDemand
                    if (shouldDropBid(dropBidProbability)) {
                        interstitial.setLocalExtraParameter(PrebidMaxMediationAdapter.EXTRA_RESPONSE_ID, "")
                    }
                    interstitial.loadAd()
                }
                result.success(null)
            }

            "show" -> {
                if (adId == null) {
                    result.error("no_ad_id", "Missing adId", null)
                    return
                }
                val activity = activityProvider()
                val ad = ads[adId]?.interstitial
                when {
                    ad == null || !ad.isReady ->
                        send(adId, "onAdFailed", "The interstitial is not ready to show; wait for onAdLoaded")
                    activity == null ->
                        send(adId, "onAdFailed", "No attached Activity to show the interstitial")
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

    private fun release(adId: Long) {
        ads.remove(adId)?.let {
            it.adUnit.destroy()
            it.interstitial.destroy()
        }
    }

    private fun send(adId: Long, event: String, error: String? = null) {
        val payload = mutableMapOf<String, Any?>("adId" to adId)
        if (error != null) payload["error"] = error
        channel.invokeMethod(event, payload)
    }
}
