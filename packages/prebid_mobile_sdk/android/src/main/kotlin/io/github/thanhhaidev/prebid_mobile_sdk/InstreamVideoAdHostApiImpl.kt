package io.github.thanhhaidev.prebid_mobile_sdk

import org.prebid.mobile.AdSize
import org.prebid.mobile.InStreamVideoAdUnit
import org.prebid.mobile.PrebidMobile
import org.prebid.mobile.Util

/** InstreamVideoAdHostApi: Original API in-stream video demand. */
internal class InstreamVideoAdHostApiImpl : InstreamVideoAdHostApi {

    private val adUnits = mutableMapOf<Long, InStreamVideoAdUnit>()

    override fun fetchDemand(
        adId: Long,
        config: InstreamVideoAdRequestConfig,
        callback: (Result<MultiformatBidResult>) -> Unit,
    ) {
        adUnits.remove(adId)?.let(::release)
        if (!PrebidMobile.isSdkInitialized()) {
            callback(
                Result.success(
                    MultiformatBidResult(
                        resultCode = PluginErrors.NOT_INITIALIZED_CODE,
                        targetingKeywords = emptyMap(),
                    ),
                ),
            )
            return
        }
        val adUnit = InStreamVideoAdUnit(
            config.configId,
            config.width.toInt(),
            config.height.toInt(),
        )
        config.videoConfig?.let { adUnit.videoParameters = it.toVideoParameters() }
        config.gpid?.let(adUnit::setGpid)
        config.pbAdSlot?.let(adUnit::setPbAdSlot)
        config.impOrtbConfig?.let(adUnit::setImpOrtbConfig)
        config.globalOrtbConfig?.let(adUnit::setGlobalOrtbConfig)
        adUnits[adId] = adUnit

        inFlight += adUnit
        adUnit.fetchDemand { bidInfo ->
            inFlight -= adUnit
            if (adUnits[adId] !== adUnit) adUnit.destroy()
            callback(Result.success(bidInfo.toMultiformatResult().copy(winningFormat = "video")))
        }
    }

    // Units with an auction running are destroyed once it returns, so the
    // pending Dart Future still completes (see MultiformatAdHostApiImpl).
    private val inFlight = mutableSetOf<InStreamVideoAdUnit>()

    private fun release(adUnit: InStreamVideoAdUnit) {
        if (adUnit !in inFlight) adUnit.destroy()
    }

    override fun destroy(adId: Long) {
        adUnits.remove(adId)?.let(::release)
    }

    override fun generateInstreamUriForGam(
        adUnitId: String,
        sizes: List<Long>,
        keywords: Map<String, String>,
    ): String {
        val adSizes = sizes.chunked(2).filter { it.size == 2 }
            .mapTo(HashSet()) { (w, h) -> AdSize(w.toInt(), h.toInt()) }
        return Util.generateInstreamUriForGam(adUnitId, adSizes, keywords)
    }

    fun destroyAll() {
        adUnits.keys.toList().forEach(::destroy)
    }
}
