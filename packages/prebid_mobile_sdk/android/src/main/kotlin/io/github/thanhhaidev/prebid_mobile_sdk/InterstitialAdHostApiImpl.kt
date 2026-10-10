package io.github.thanhhaidev.prebid_mobile_sdk

import android.app.Activity
import java.util.EnumSet
import org.prebid.mobile.AdSize
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.api.data.AdUnitFormat
import org.prebid.mobile.api.exceptions.AdException
import org.prebid.mobile.api.rendering.InterstitialAdUnit
import org.prebid.mobile.api.rendering.listeners.InterstitialAdUnitListener

/** InterstitialAdHostApi: rendering interstitials (Prebid renders). */
internal class InterstitialAdHostApiImpl(
    private val flutterApi: AdFlutterApi,
    private val activity: () -> Activity?,
) : InterstitialAdHostApi {

    private val interstitialAds = mutableMapOf<Long, InterstitialAdUnit>()

    override fun loadAd(
        adId: Long,
        configId: String,
        adFormats: List<String>?,
        videoConfig: VideoParametersConfig?,
        impOrtbConfig: String?,
        globalOrtbConfig: String?,
        controls: FullscreenControlsConfig?,
        pbAdSlot: String?,
    ) {
        // A reload replaces the previous unit; destroy it so it stops sending
        // events under this ad id.
        interstitialAds.remove(adId)?.destroy()
        if (!PrebidMobile.isSdkInitialized()) return flutterApi.sendAdFailed(adId, PluginErrors.NOT_INITIALIZED)
        val act = activity() ?: return flutterApi.sendAdFailed(adId, PluginErrors.NO_ACTIVITY)

        // Build EnumSet for ad formats
        val formats = EnumSet.noneOf(AdUnitFormat::class.java)
        adFormats?.forEach { f ->
            when (f) {
                "banner" -> formats.add(AdUnitFormat.BANNER)
                "video" -> formats.add(AdUnitFormat.VIDEO)
            }
        }
        if (formats.isEmpty()) {
            formats.add(AdUnitFormat.BANNER)
        }

        val adUnit = InterstitialAdUnit(act, configId, formats)

        // The Android rendering InterstitialAdUnit has no public video-parameters
        // setter (mimes/protocols/etc. come from the SDK defaults); only the max
        // duration is configurable.
        videoConfig?.maxDuration?.let { adUnit.setMaxVideoDuration(it.toInt()) }
        impOrtbConfig?.let { adUnit.setImpOrtbConfig(it) }
        globalOrtbConfig?.let { adUnit.setGlobalOrtbConfig(it) }
        pbAdSlot?.let { adUnit.setPbAdSlot(it) }
        controls?.let { c ->
            c.applyTo(adUnit)
            if (c.minWidthPercentage != null && c.minHeightPercentage != null) {
                adUnit.setMinSizePercentage(
                    AdSize(c.minWidthPercentage.toInt(), c.minHeightPercentage.toInt())
                )
            }
        }

        adUnit.setInterstitialAdUnitListener(object : InterstitialAdUnitListener {
            override fun onAdLoaded(unit: InterstitialAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdLoaded")) {}
            }
            override fun onAdFailed(unit: InterstitialAdUnit, e: AdException?) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdFailed", error = e?.message)) {}
            }
            override fun onAdDisplayed(unit: InterstitialAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdDisplayed")) {}
            }
            override fun onAdClosed(unit: InterstitialAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdClosed")) {}
            }
            override fun onAdClicked(unit: InterstitialAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdClicked")) {}
            }
            override fun onAdExpired(unit: InterstitialAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdExpired")) {}
            }
        })

        interstitialAds[adId] = adUnit
        adUnit.loadAd()
    }

    override fun show(adId: Long) {
        val adUnit = interstitialAds[adId]
        if (adUnit == null || !adUnit.isLoaded) return flutterApi.sendAdFailed(adId, PluginErrors.NOT_READY)
        adUnit.show()
    }

    override fun destroy(adId: Long) {
        interstitialAds.remove(adId)?.destroy()
    }

    /** Destroys every unit and returns their ad ids. */
    fun destroyAll(): List<Long> {
        val ids = interstitialAds.keys.toList()
        ids.forEach { interstitialAds.remove(it)?.destroy() }
        return ids
    }
}
