package io.github.thanhhaidev.prebid_mobile_sdk_max

import android.app.Activity
import com.applovin.mediation.MaxAd
import com.applovin.mediation.MaxError
import com.applovin.mediation.MaxReward
import com.applovin.mediation.MaxRewardedAdListener
import com.applovin.mediation.adapters.PrebidMaxMediationAdapter
import com.applovin.mediation.adapters.prebid.utils.MaxMediationRewardedUtils
import com.applovin.mediation.ads.MaxRewardedAd
import io.flutter.plugin.common.BinaryMessenger
import org.prebid.mobile.api.mediation.MediationRewardedVideoAdUnit

/**
 * MAX-mediated rewarded ads over the `prebid_mobile_sdk_max/rewarded` method
 * channel.
 *
 * MAX hands out one shared [MaxRewardedAd] per ad unit, so at most one `adId`
 * owns a unit at a time: a new load on the same unit takes it over (the
 * previous owner gets `onAdFailed`), and only the owner may destroy it.
 * While the owner's ad is on screen the unit cannot be handed over (its
 * reward and close would reach the new owner), so a load on it fails.
 */
internal class MaxRewardedManager(
    messenger: BinaryMessenger,
    activityProvider: () -> Activity?,
) : FullscreenAdManager<MaxRewardedManager.Ad>(
    messenger,
    "prebid_mobile_sdk_max/rewarded",
    activityProvider,
) {

    /** One rewarded ad: the Prebid ad unit and the shared MAX ad it bids into. */
    class Ad(
        val adUnit: MediationRewardedVideoAdUnit,
        val rewarded: MaxRewardedAd,
        val dropBidProbability: Double,
    )

    /** MAX ad unit id → the `adId` that currently owns its shared instance. */
    private val ownerByUnit = mutableMapOf<String, Long>()

    /**
     * MAX ad units whose ad is on screen (from displayed until hidden or
     * display-failed).
     */
    private val showingUnits = mutableSetOf<String>()

    // Handing the shared instance over now would route the showing ad's
    // reward and close to this ad; leave it alone.
    override fun refuseLoad(adId: Long, args: Map<*, *>): String? =
        SHOWING_ERROR.takeIf { maxAdUnitId(args) in showingUnits }

    override fun create(adId: Long, args: Map<*, *>, activity: Activity): Ad {
        val configId = args["configId"] as? String ?: ""
        val maxAdUnitId = maxAdUnitId(args)

        // The shared instance moves to this adId; the previous owner stops
        // receiving events (the listener is replaced below) and is told why.
        // Its Prebid ad unit is freed, the MAX ad is not.
        ownerByUnit[maxAdUnitId]?.takeIf { it != adId }?.let { previous ->
            ads.remove(previous)?.adUnit?.destroy()
            send(previous, "onAdFailed", "Replaced by another ad on the same MAX ad unit")
        }
        ownerByUnit[maxAdUnitId] = adId

        val rewarded = MaxRewardedAd.getInstance(maxAdUnitId, activity)
        rewarded.setListener(object : MaxRewardedAdListener {
            override fun onAdLoaded(ad: MaxAd) = send(adId, "onAdLoaded")
            override fun onAdDisplayed(ad: MaxAd) {
                showingUnits.add(maxAdUnitId)
                send(adId, "onAdDisplayed")
            }
            override fun onAdHidden(ad: MaxAd) {
                showingUnits.remove(maxAdUnitId)
                send(adId, "onAdClosed")
            }
            override fun onAdClicked(ad: MaxAd) = send(adId, "onAdClicked")
            override fun onAdLoadFailed(adUnitId: String, error: MaxError) =
                send(adId, "onAdFailed", errorMessage(error.message))
            override fun onAdDisplayFailed(ad: MaxAd, error: MaxError) {
                showingUnits.remove(maxAdUnitId)
                send(adId, "onAdFailed", errorMessage(error.message))
            }
            override fun onUserRewarded(ad: MaxAd, reward: MaxReward) {
                // Same reward keys as the GAM / AdMob packages.
                send(
                    adId,
                    "onUserEarnedReward",
                    mapOf("rewardType" to reward.label, "rewardCount" to reward.amount),
                )
            }
        })
        // MAX reports revenue when the impression is recorded.
        rewarded.setRevenueListener { ad ->
            send(adId, "onAdImpression")
            send(adId, "onAdRevenuePaid", revenuePayload(ad))
        }

        val adUnit = MediationRewardedVideoAdUnit(activity, configId, MaxMediationRewardedUtils(rewarded))
        (args["impOrtbConfig"] as? String)?.let { adUnit.setImpOrtbConfig(it) }
        (args["globalOrtbConfig"] as? String)?.let { adUnit.setGlobalOrtbConfig(it) }
        (args["pbAdSlot"] as? String)?.let { adUnit.setPbAdSlot(it) }
        FullscreenControls.from(args["controls"])?.applyTo(adUnit)
        videoMaxDurationFrom(args["videoParameters"])?.let { adUnit.setMaxVideoDuration(it) }
        return Ad(adUnit, rewarded, debugDropBidProbability(args["debugDropBidProbability"]))
    }

    override fun start(adId: Long, ad: Ad) {
        ad.adUnit.fetchDemand {
            // Destroyed / replaced while the auction ran: skip the load.
            if (ads[adId] !== ad) return@fetchDemand
            if (shouldDropBid(ad.dropBidProbability)) {
                ad.rewarded.setLocalExtraParameter(PrebidMaxMediationAdapter.EXTRA_RESPONSE_ID, "")
            }
            ad.rewarded.loadAd()
        }
    }

    override fun isReady(ad: Ad): Boolean = ad.rewarded.isReady

    override fun show(ad: Ad, activity: Activity) = ad.rewarded.showAd(activity)

    /**
     * The shared MAX instance is destroyed only when [adId] still owns its
     * unit: a replaced ad must not destroy the instance the new owner uses.
     */
    override fun destroy(adId: Long, ad: Ad) {
        ad.adUnit.destroy()
        val unitId = ad.rewarded.adUnitId
        if (ownerByUnit[unitId] == adId) {
            ownerByUnit.remove(unitId)
            showingUnits.remove(unitId)
            ad.rewarded.destroy()
        }
    }

    private fun maxAdUnitId(args: Map<*, *>): String = args["maxAdUnitId"] as? String ?: ""

    private companion object {
        const val SHOWING_ERROR =
            "Another ad for this MAX ad unit is showing; load the next one after onAdClosed"
    }
}
