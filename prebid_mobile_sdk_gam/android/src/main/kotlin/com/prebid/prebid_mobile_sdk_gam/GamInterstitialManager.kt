package com.prebid.prebid_mobile_sdk_gam

import android.app.Activity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.prebid.mobile.api.exceptions.AdException
import org.prebid.mobile.api.rendering.InterstitialAdUnit
import org.prebid.mobile.api.rendering.listeners.InterstitialAdUnitListener
import org.prebid.mobile.eventhandlers.GamInterstitialEventHandler

/// Handles GAM-rendered interstitials over the `prebid_mobile_sdk_gam/interstitial`
/// method channel. Each ad is keyed by an `adId` allocated on the Dart side;
/// native events are pushed back over the same channel.
class GamInterstitialManager(
    messenger: BinaryMessenger,
    private val activityProvider: () -> Activity?,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "prebid_mobile_sdk_gam/interstitial")
    private val ads = mutableMapOf<Long, InterstitialAdUnit>()

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
                    result.error("no_activity", "No attached Activity to load the interstitial", null)
                    return
                }
                if (adId == null) {
                    result.error("no_ad_id", "Missing adId", null)
                    return
                }
                val configId = args?.get("configId") as? String ?: ""
                val gamAdUnitId = args?.get("gamAdUnitId") as? String ?: ""

                val eventHandler = GamInterstitialEventHandler(activity, gamAdUnitId)
                val adUnit = InterstitialAdUnit(activity, configId, eventHandler)

                adUnit.setInterstitialAdUnitListener(object : InterstitialAdUnitListener {
                    override fun onAdLoaded(unit: InterstitialAdUnit) = send(adId, "onAdLoaded")
                    override fun onAdFailed(unit: InterstitialAdUnit, e: AdException?) =
                        send(adId, "onAdFailed", e?.message ?: "Unknown error")
                    override fun onAdDisplayed(unit: InterstitialAdUnit) = send(adId, "onAdDisplayed")
                    override fun onAdClosed(unit: InterstitialAdUnit) = send(adId, "onAdClosed")
                    override fun onAdClicked(unit: InterstitialAdUnit) = send(adId, "onAdClicked")
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

    private fun send(adId: Long, event: String, error: String? = null) {
        val payload = mutableMapOf<String, Any?>("adId" to adId)
        if (error != null) payload["error"] = error
        channel.invokeMethod(event, payload)
    }
}
