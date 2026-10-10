package io.github.thanhhaidev.prebid_mobile_sdk_gam

import android.app.Activity
import io.flutter.plugin.common.BinaryMessenger
import org.prebid.mobile.AdSize
import org.prebid.mobile.api.exceptions.AdException
import org.prebid.mobile.api.rendering.InterstitialAdUnit
import org.prebid.mobile.api.rendering.listeners.InterstitialAdUnitListener
import org.prebid.mobile.eventhandlers.GamInterstitialEventHandler

/**
 * GAM-rendered interstitials over the `prebid_mobile_sdk_gam/interstitial`
 * method channel.
 */
internal class GamInterstitialManager(
    messenger: BinaryMessenger,
    activityProvider: () -> Activity?,
) : FullscreenAdManager<InterstitialAdUnit>(
    messenger,
    "prebid_mobile_sdk_gam/interstitial",
    activityProvider,
) {

    override fun create(activity: Activity, adId: Long, args: Map<*, *>): InterstitialAdUnit {
        val configId = args["configId"] as? String ?: ""
        val gamAdUnitId = args["gamAdUnitId"] as? String ?: ""
        val isVideo = args["isVideo"] as? Boolean ?: false
        val eventHandler = GamInterstitialEventHandler(activity, gamAdUnitId).apply {
            gamCustomTargeting(args["customTargeting"])?.let { targeting ->
                // Prebid 3.4: app custom targeting on the GAM request; Prebid's
                // hb_* keys still take precedence.
                setAdManagerRequestConfiguration { builder ->
                    targeting.forEach { (k, v) -> builder.addCustomTargeting(k, v) }
                }
            }
        }
        val adUnit = InterstitialAdUnit(
            activity,
            configId,
            adUnitFormats(args["adFormats"], isVideo),
            eventHandler,
        )
        videoMaxDurationFrom(args["videoParameters"])?.let { adUnit.setMaxVideoDuration(it) }
        (args["impOrtbConfig"] as? String)?.let { adUnit.setImpOrtbConfig(it) }
        FullscreenControls.from(args["controls"])?.let { controls ->
            controls.applyTo(adUnit)
            if (controls.minWidthPercentage != null && controls.minHeightPercentage != null) {
                adUnit.setMinSizePercentage(
                    AdSize(controls.minWidthPercentage, controls.minHeightPercentage)
                )
            }
        }
        adUnit.setInterstitialAdUnitListener(object : InterstitialAdUnitListener {
            override fun onAdLoaded(unit: InterstitialAdUnit) = send(adId, "onAdLoaded")
            override fun onAdFailed(unit: InterstitialAdUnit, e: AdException?) =
                send(adId, "onAdFailed", e?.message ?: PluginErrors.UNKNOWN)
            override fun onAdDisplayed(unit: InterstitialAdUnit) = send(adId, "onAdDisplayed")
            override fun onAdClosed(unit: InterstitialAdUnit) = send(adId, "onAdClosed")
            override fun onAdClicked(unit: InterstitialAdUnit) = send(adId, "onAdClicked")
            override fun onAdExpired(unit: InterstitialAdUnit) = send(adId, "onAdExpired")
        })
        return adUnit
    }
}
