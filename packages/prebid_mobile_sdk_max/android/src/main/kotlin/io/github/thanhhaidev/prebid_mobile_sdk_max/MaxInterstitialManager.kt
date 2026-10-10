package io.github.thanhhaidev.prebid_mobile_sdk_max

import android.app.Activity
import com.applovin.mediation.MaxAd
import com.applovin.mediation.MaxAdListener
import com.applovin.mediation.MaxError
import com.applovin.mediation.adapters.PrebidMaxMediationAdapter
import com.applovin.mediation.adapters.prebid.utils.MaxMediationInterstitialUtils
import com.applovin.mediation.ads.MaxInterstitialAd
import io.flutter.plugin.common.BinaryMessenger
import org.prebid.mobile.api.mediation.MediationInterstitialAdUnit

/**
 * MAX-mediated interstitials over the `prebid_mobile_sdk_max/interstitial`
 * method channel.
 */
internal class MaxInterstitialManager(
    messenger: BinaryMessenger,
    activityProvider: () -> Activity?,
) : FullscreenAdManager<MaxInterstitialManager.Ad>(
    messenger,
    "prebid_mobile_sdk_max/interstitial",
    activityProvider,
) {

    /** One interstitial: the Prebid ad unit and the MAX ad it bids into. */
    class Ad(
        val adUnit: MediationInterstitialAdUnit,
        val interstitial: MaxInterstitialAd,
        val dropBidProbability: Double,
    )

    override fun create(adId: Long, args: Map<*, *>, activity: Activity): Ad {
        val configId = args["configId"] as? String ?: ""
        val maxAdUnitId = args["maxAdUnitId"] as? String ?: ""
        val isVideo = args["isVideo"] as? Boolean ?: false

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
            send(adId, "onAdRevenuePaid", extras = revenuePayload(ad))
        }

        val adUnit = MediationInterstitialAdUnit(
            activity,
            configId,
            adUnitFormats(args["adFormats"], isVideo),
            MaxMediationInterstitialUtils(interstitial),
        )
        (args["impOrtbConfig"] as? String)?.let { adUnit.setImpOrtbConfig(it) }
        (args["globalOrtbConfig"] as? String)?.let { adUnit.setGlobalOrtbConfig(it) }
        (args["pbAdSlot"] as? String)?.let { adUnit.setPbAdSlot(it) }
        FullscreenControls.from(args["controls"])?.applyTo(adUnit)
        videoMaxDurationFrom(args["videoParameters"])?.let { adUnit.setMaxVideoDuration(it) }
        return Ad(adUnit, interstitial, debugDropBidProbability(args["debugDropBidProbability"]))
    }

    override fun load(adId: Long, ad: Ad, activity: Activity) {
        ad.adUnit.fetchDemand {
            // Destroyed / replaced while the auction ran: skip the load.
            if (!isCurrent(adId, ad)) return@fetchDemand
            if (shouldDropBid(ad.dropBidProbability)) {
                ad.interstitial.setLocalExtraParameter(PrebidMaxMediationAdapter.EXTRA_RESPONSE_ID, "")
            }
            ad.interstitial.loadAd()
        }
    }

    override fun isLoaded(ad: Ad): Boolean = ad.interstitial.isReady

    override fun show(adId: Long, ad: Ad, activity: Activity) = ad.interstitial.showAd(activity)

    override fun destroy(adId: Long, ad: Ad) {
        ad.adUnit.destroy()
        ad.interstitial.destroy()
    }
}
