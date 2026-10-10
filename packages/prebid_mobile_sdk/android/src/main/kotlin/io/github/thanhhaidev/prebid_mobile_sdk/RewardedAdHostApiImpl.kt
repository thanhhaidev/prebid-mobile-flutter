package io.github.thanhhaidev.prebid_mobile_sdk

import android.app.Activity
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.api.exceptions.AdException
import org.prebid.mobile.api.rendering.RewardedAdUnit
import org.prebid.mobile.api.rendering.listeners.RewardedAdUnitListener
import org.prebid.mobile.rendering.interstitial.rewarded.Reward

/** RewardedAdHostApi: rendering rewarded ads (Prebid renders). */
internal class RewardedAdHostApiImpl(
    private val flutterApi: AdFlutterApi,
    private val activity: () -> Activity?
) : RewardedAdHostApi {

    private val rewardedAds = mutableMapOf<Long, RewardedAdUnit>()

    override fun loadAd(
        adId: Long,
        configId: String,
        adFormats: List<String>?,
        videoConfig: VideoParametersConfig?,
        impOrtbConfig: String?,
        globalOrtbConfig: String?,
        controls: FullscreenControlsConfig?,
        pbAdSlot: String?,
        adPosition: Long?,
    ) {
        rewardedAds.remove(adId)?.destroy()
        if (!PrebidMobile.isSdkInitialized()) {
            return flutterApi.sendAdFailed(adId, PluginErrors.NOT_INITIALIZED)
        }
        val act = activity() ?: return flutterApi.sendAdFailed(adId, PluginErrors.NO_ACTIVITY)
        // Prebid Android's RewardedAdUnit has no ad formats, video parameters
        // (beyond the rendered video's max duration) or minimum size: those
        // apply on iOS only.
        val adUnit = RewardedAdUnit(act, configId)
        videoConfig?.maxDuration?.let { adUnit.setMaxVideoDuration(it.toInt()) }
        impOrtbConfig?.let(adUnit::setImpOrtbConfig)
        globalOrtbConfig?.let(adUnit::setGlobalOrtbConfig)
        pbAdSlot?.let(adUnit::setPbAdSlot)
        controls?.applyTo(adUnit)

        adUnit.setRewardedAdUnitListener(object : RewardedAdUnitListener {
            override fun onAdLoaded(unit: RewardedAdUnit) {
                val bid = unit.bidResponse?.toWinningBidData()
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdLoaded", winningBid = bid)) {}
            }
            override fun onAdFailed(unit: RewardedAdUnit, e: AdException?) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdFailed", error = e?.message)) {}
            }
            override fun onAdDisplayed(unit: RewardedAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdDisplayed")) {}
            }
            override fun onAdClosed(unit: RewardedAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdClosed")) {}
            }
            override fun onAdClicked(unit: RewardedAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdClicked")) {}
            }
            override fun onAdExpired(unit: RewardedAdUnit) {
                flutterApi.onAdEvent(AdEvent(adId = adId, eventName = "onAdExpired")) {}
            }
            override fun onUserEarnedReward(unit: RewardedAdUnit, reward: Reward?) {
                flutterApi.onAdEvent(AdEvent(
                    adId = adId,
                    eventName = "onUserEarnedReward",
                    reward = RewardData(
                        type = reward?.type ?: "reward",
                        count = reward?.count?.toLong() ?: 1,
                        ext = reward?.ext?.toMap(),
                    )
                )) {}
            }
        })

        rewardedAds[adId] = adUnit
        adUnit.loadAd()
    }

    override fun show(adId: Long) {
        val adUnit = rewardedAds[adId]
        if (adUnit == null || !adUnit.isLoaded) {
            return flutterApi.sendAdFailed(adId, PluginErrors.NOT_READY)
        }
        adUnit.show()
    }

    override fun destroy(adId: Long) {
        rewardedAds.remove(adId)?.destroy()
    }

    /** Destroys every rewarded unit and returns their ad ids. */
    fun destroyAll(): List<Long> {
        val ids = rewardedAds.keys.toList()
        ids.forEach { rewardedAds.remove(it)?.destroy() }
        return ids
    }
}
