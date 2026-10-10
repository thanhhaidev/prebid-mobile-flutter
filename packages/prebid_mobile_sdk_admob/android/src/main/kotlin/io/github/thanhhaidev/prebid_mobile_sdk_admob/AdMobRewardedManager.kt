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
import org.prebid.mobile.admob.AdMobMediationRewardedUtils
import org.prebid.mobile.admob.PrebidRewardedAdapter
import org.prebid.mobile.api.mediation.MediationRewardedVideoAdUnit

/**
 * AdMob-mediated rewarded ads over the `prebid_mobile_sdk_admob/rewarded`
 * method channel: Prebid's [MediationRewardedVideoAdUnit] runs the auction
 * and the winning bid reaches AdMob's [RewardedAd] through the Prebid
 * adapter. The reward is sent as `onUserEarnedReward`.
 */
internal class AdMobRewardedManager(
    messenger: BinaryMessenger,
    activityProvider: () -> Activity?,
) : FullscreenAdManager<AdMobRewardedManager.Ad>(
    messenger,
    "prebid_mobile_sdk_admob/rewarded",
    activityProvider,
) {

    /** One rewarded ad: the Prebid ad unit and, once loaded, the AdMob ad. */
    internal class Ad(
        val adUnit: MediationRewardedVideoAdUnit,
        val adMobAdUnitId: String,
        val extras: Bundle,
        val request: AdRequest,
        val dropBidProbability: Double,
    ) {
        var rewarded: RewardedAd? = null
    }

    override fun create(adId: Long, args: Map<*, *>, activity: Activity): Ad {
        val extras = Bundle()
        // Prebid writes the bid's response id into `extras` for the adapter.
        val request = AdRequest.Builder()
            .addNetworkExtrasBundle(PrebidRewardedAdapter::class.java, extras)
            .build()
        val adUnit = MediationRewardedVideoAdUnit(
            activity,
            args["configId"] as? String ?: "",
            AdMobMediationRewardedUtils(extras),
        )
        (args["impOrtbConfig"] as? String)?.let { adUnit.setImpOrtbConfig(it) }
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
            maybeDropBid(ad.dropBidProbability, ad.extras, PrebidRewardedAdapter.EXTRA_RESPONSE_ID)
            RewardedAd.load(
                activity,
                ad.adMobAdUnitId,
                ad.request,
                object : RewardedAdLoadCallback() {
                    override fun onAdLoaded(rewarded: RewardedAd) {
                        if (!isCurrent(adId, ad)) return
                        ad.rewarded = rewarded
                        rewarded.fullScreenContentCallback = fullScreenCallback(adId)
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

    override fun isLoaded(ad: Ad): Boolean = ad.rewarded != null

    override fun show(adId: Long, ad: Ad, activity: Activity) {
        ad.rewarded?.show(activity) { reward ->
            if (!isCurrent(adId, ad)) return@show
            // Same reward keys as the GAM / MAX packages.
            send(
                adId,
                "onUserEarnedReward",
                extra = mapOf("rewardType" to reward.type, "rewardCount" to reward.amount),
            )
        }
    }

    override fun destroy(ad: Ad) {
        ad.rewarded?.fullScreenContentCallback = null
        ad.rewarded = null
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
