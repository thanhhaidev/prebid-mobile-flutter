package com.prebid.prebid_mobile_sdk_gam

import android.app.Activity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.prebid.mobile.api.exceptions.AdException
import org.prebid.mobile.api.data.AdUnitFormat
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
                // Reloading an adId replaces (and frees) its previous ad unit.
                ads.remove(adId)?.destroy()
                val configId = args?.get("configId") as? String ?: ""
                val gamAdUnitId = args?.get("gamAdUnitId") as? String ?: ""
                val formats = java.util.EnumSet.noneOf(AdUnitFormat::class.java)
                (args?.get("adFormats") as? List<*>)?.forEach { format ->
                    when (format as? String) {
                        "banner" -> formats.add(AdUnitFormat.BANNER)
                        "video" -> formats.add(AdUnitFormat.VIDEO)
                    }
                }
                if (formats.isEmpty()) formats.add(AdUnitFormat.BANNER)

                val eventHandler = GamInterstitialEventHandler(activity, gamAdUnitId).apply {
                    gamCustomTargeting(args?.get("customTargeting"))?.let { targeting ->
                        // Prebid 3.4: app custom targeting on the GAM request; Prebid's
                        // hb_* keys still take precedence.
                        setAdManagerRequestConfiguration { builder ->
                            targeting.forEach { (k, v) -> builder.addCustomTargeting(k, v) }
                        }
                    }
                }
                val adUnit = InterstitialAdUnit(activity, configId, formats, eventHandler)
                FullscreenControls.from(args?.get("controls"))?.let { controls ->
                    controls.applyTo(adUnit)
                    if (controls.minWidthPercentage != null && controls.minHeightPercentage != null) {
                        adUnit.setMinSizePercentage(
                            org.prebid.mobile.AdSize(controls.minWidthPercentage, controls.minHeightPercentage)
                        )
                    }
                }

                adUnit.setInterstitialAdUnitListener(object : InterstitialAdUnitListener {
                    override fun onAdLoaded(unit: InterstitialAdUnit) = send(adId, "onAdLoaded")
                    override fun onAdFailed(unit: InterstitialAdUnit, e: AdException?) =
                        send(adId, "onAdFailed", e?.message ?: "Unknown error")
                    override fun onAdDisplayed(unit: InterstitialAdUnit) = send(adId, "onAdDisplayed")
                    override fun onAdClosed(unit: InterstitialAdUnit) = send(adId, "onAdClosed")
                    override fun onAdClicked(unit: InterstitialAdUnit) = send(adId, "onAdClicked")
                    override fun onAdExpired(unit: InterstitialAdUnit) = send(adId, "onAdExpired")
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
                        send(adId, "onAdFailed", "The interstitial is not ready to show; wait for onAdLoaded")
                    // Prebid shows from the Activity the ad unit was loaded with.
                    activityProvider() == null ->
                        send(adId, "onAdFailed", "No attached Activity to show the interstitial")
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

    private fun send(adId: Long, event: String, error: String? = null) {
        val payload = mutableMapOf<String, Any?>("adId" to adId)
        if (error != null) payload["error"] = error
        channel.invokeMethod(event, payload)
    }
}
