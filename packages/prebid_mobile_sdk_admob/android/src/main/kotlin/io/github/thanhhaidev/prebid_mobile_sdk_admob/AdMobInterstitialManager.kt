package io.github.thanhhaidev.prebid_mobile_sdk_admob

import android.app.Activity
import android.os.Bundle
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import io.flutter.plugin.common.BinaryMessenger
import org.prebid.mobile.admob.AdMobMediationInterstitialUtils
import org.prebid.mobile.admob.PrebidInterstitialAdapter
import org.prebid.mobile.api.mediation.MediationInterstitialAdUnit

/**
 * AdMob-mediated interstitials over the `prebid_mobile_sdk_admob/interstitial`
 * method channel: Prebid's [MediationInterstitialAdUnit] runs the auction and
 * the winning bid reaches AdMob's [InterstitialAd] through the Prebid adapter.
 */
internal class AdMobInterstitialManager(
    messenger: BinaryMessenger,
    activityProvider: () -> Activity?,
) : FullscreenAdManager<AdMobInterstitialManager.Ad>(
    messenger,
    "prebid_mobile_sdk_admob/interstitial",
    activityProvider,
) {

    /** One interstitial: the Prebid ad unit and, once loaded, the AdMob ad. */
    internal class Ad(
        val adUnit: MediationInterstitialAdUnit,
        val adMobAdUnitId: String,
        val extras: Bundle,
        val request: AdRequest,
        val dropBidProbability: Double,
    ) {
        var interstitial: InterstitialAd? = null
    }

    override fun create(adId: Long, args: Map<*, *>, activity: Activity): Ad {
        val extras = Bundle()
        // Prebid writes the bid's response id into `extras` for the adapter.
        val request = AdRequest.Builder()
            .addNetworkExtrasBundle(PrebidInterstitialAdapter::class.java, extras)
            .build()
        val adUnit = MediationInterstitialAdUnit(
            activity,
            args["configId"] as? String ?: "",
            adUnitFormats(args["adFormats"], args["isVideo"] as? Boolean ?: false),
            AdMobMediationInterstitialUtils(extras),
        )
        (args["impOrtbConfig"] as? String)?.let { adUnit.setImpOrtbConfig(it) }
        (args["globalOrtbConfig"] as? String)?.let { adUnit.setGlobalOrtbConfig(it) }
        (args["pbAdSlot"] as? String)?.let { adUnit.setPbAdSlot(it) }
        FullscreenControls.from(args["controls"])?.applyTo(adUnit)
        videoMaxDurationFrom(args["videoParameters"])?.let { adUnit.setMaxVideoDuration(it) }
        return Ad(
            adUnit,
            args["adMobAdUnitId"] as? String ?: "",
            extras,
            request,
            debugDropBidProbability(args["debugDropBidProbability"]),
        )
    }

    override fun load(adId: Long, ad: Ad, activity: Activity) {
        ad.adUnit.fetchDemand {
            // Destroyed / replaced while the auction ran: skip the load.
            if (!isCurrent(adId, ad)) return@fetchDemand
            maybeDropBid(ad.dropBidProbability, ad.extras, PrebidInterstitialAdapter.EXTRA_RESPONSE_ID)
            InterstitialAd.load(
                activity,
                ad.adMobAdUnitId,
                ad.request,
                object : InterstitialAdLoadCallback() {
                    override fun onAdLoaded(interstitial: InterstitialAd) {
                        if (!isCurrent(adId, ad)) return
                        ad.interstitial = interstitial
                        interstitial.fullScreenContentCallback = fullScreenCallback(adId)
                        send(adId, "onAdLoaded")
                    }

                    override fun onAdFailedToLoad(error: LoadAdError) {
                        if (!isCurrent(adId, ad)) return
                        send(adId, "onAdFailed", error.message)
                    }
                },
            )
        }
    }

    override fun isLoaded(ad: Ad): Boolean = ad.interstitial != null

    override fun show(adId: Long, ad: Ad, activity: Activity) {
        ad.interstitial?.show(activity)
    }

    override fun destroy(adId: Long, ad: Ad) {
        ad.interstitial?.fullScreenContentCallback = null
        ad.interstitial = null
        ad.adUnit.destroy()
    }

    private fun fullScreenCallback(adId: Long) = object : FullScreenContentCallback() {
        override fun onAdShowedFullScreenContent() = send(adId, "onAdDisplayed")
        override fun onAdDismissedFullScreenContent() = send(adId, "onAdClosed")
        override fun onAdClicked() = send(adId, "onAdClicked")
        override fun onAdImpression() = send(adId, "onAdImpression")
        override fun onAdFailedToShowFullScreenContent(error: AdError) =
            send(adId, "onAdFailed", error.message)
    }
}
