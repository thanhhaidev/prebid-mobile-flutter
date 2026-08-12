package com.prebid.prebid_mobile_sdk_admob

import android.app.Activity
import android.os.Bundle
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.prebid.mobile.admob.AdMobMediationInterstitialUtils
import org.prebid.mobile.admob.PrebidInterstitialAdapter
import org.prebid.mobile.api.data.AdUnitFormat
import org.prebid.mobile.api.mediation.MediationInterstitialAdUnit
import java.util.EnumSet

/// Handles AdMob-mediated interstitials over the
/// `prebid_mobile_sdk_admob/interstitial` method channel. Each ad is keyed by an
/// `adId` allocated on the Dart side; native events are pushed back over the
/// same channel.
class AdMobInterstitialManager(
    messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "prebid_mobile_sdk_admob/interstitial")

    private class Holder(val adUnit: MediationInterstitialAdUnit) {
        var interstitial: InterstitialAd? = null
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
                    result.error("no_activity", "No attached Activity to load the interstitial", null)
                    return
                }
                if (adId == null) {
                    result.error("no_ad_id", "Missing adId", null)
                    return
                }
                val configId = args?.get("configId") as? String ?: ""
                val adMobAdUnitId = args?.get("adMobAdUnitId") as? String ?: ""
                val isVideo = args?.get("isVideo") as? Boolean ?: false

                val extras = Bundle()
                val request = AdRequest.Builder()
                    .addNetworkExtrasBundle(PrebidInterstitialAdapter::class.java, extras)
                    .build()

                val mediationUtils = AdMobMediationInterstitialUtils(extras)
                val format = if (isVideo) AdUnitFormat.VIDEO else AdUnitFormat.BANNER
                val adUnit = MediationInterstitialAdUnit(
                    activity,
                    configId,
                    EnumSet.of(format),
                    mediationUtils,
                )
                val holder = Holder(adUnit)
                ads[adId] = holder

                adUnit.fetchDemand {
                    InterstitialAd.load(
                        activity,
                        adMobAdUnitId,
                        request,
                        object : InterstitialAdLoadCallback() {
                            override fun onAdLoaded(ad: InterstitialAd) {
                                holder.interstitial = ad
                                ad.fullScreenContentCallback = fullScreenCallback(adId)
                                send(adId, "onAdLoaded")
                            }

                            override fun onAdFailedToLoad(error: LoadAdError) {
                                holder.interstitial = null
                                send(adId, "onAdFailed", error.message)
                            }
                        },
                    )
                }
                result.success(null)
            }

            "show" -> {
                val activity = activityProvider()
                val ad = adId?.let { ads[it]?.interstitial }
                if (ad != null && activity != null) {
                    ad.show(activity)
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
