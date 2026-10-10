package io.github.thanhhaidev.prebid_mobile_sdk_admob

import android.os.Bundle
import java.util.EnumSet
import kotlin.random.Random
import org.prebid.mobile.api.data.AdUnitFormat
import org.prebid.mobile.api.mediation.MediationBaseFullScreenAdUnit
import org.prebid.mobile.api.mediation.MediationInterstitialAdUnit
import org.prebid.mobile.rendering.bidding.display.BidResponseCache

// This package's own helpers; the parsing every companion shares is in
// PrebidRequests.

/** What every ad reports when it loads before `PrebidMobile.initializeSdk` finished. */
internal const val SDK_NOT_INITIALIZED = "The Prebid SDK is not initialized"

/** An SDK error message for Dart; blank becomes "Unknown error". */
internal fun errorMessage(message: String?): String =
    message?.takeIf { it.isNotBlank() } ?: "Unknown error"

/**
 * The method-channel suffix of a platform view: the `channelId` creation
 * param the Dart widget listens on before the view exists (falls back to the
 * platform view id).
 */
internal fun viewChannelId(params: Map<*, *>, viewId: Int): Long =
    (params["channelId"] as? Number)?.toLong() ?: viewId.toLong()

/**
 * `debugDropBidProbability` (`PrebidAdMob.debugDropBidProbability`, testing
 * only), clamped to `0..1`; 0 when absent.
 */
internal fun debugDropBidProbability(raw: Any?): Double =
    ((raw as? Number)?.toDouble() ?: 0.0).takeIf { !it.isNaN() }?.coerceIn(0.0, 1.0) ?: 0.0

/**
 * Testing hook: with [probability], pops the Prebid bid whose response id the
 * mediation utils stored in [extras] under [responseIdKey] (the adapter's
 * `EXTRA_RESPONSE_ID`) from [BidResponseCache] — exactly what Prebid's
 * internal test app "Random" screens do — so the Prebid adapter finds no bid
 * and AdMob falls back to its waterfall. Call after `fetchDemand` completes.
 */
internal fun maybeDropBid(probability: Double, extras: Bundle, responseIdKey: String) {
    if (probability <= 0.0 || Random.nextDouble() >= probability) return
    extras.getString(responseIdKey)?.let { BidResponseCache.getInstance().popBidResponse(it) }
}

/**
 * Ad unit formats: `adFormats` (`PrebidAdFormat` names) when it names any,
 * else video or banner from `isVideo`.
 */
internal fun adUnitFormats(raw: Any?, isVideo: Boolean): EnumSet<AdUnitFormat> {
    val names = (raw as? List<*>).orEmpty().filterIsInstance<String>()
    val formats = EnumSet.noneOf(AdUnitFormat::class.java)
    if ("banner" in names) formats.add(AdUnitFormat.BANNER)
    if ("video" in names) formats.add(AdUnitFormat.VIDEO)
    if (formats.isEmpty()) {
        formats.add(if (isVideo) AdUnitFormat.VIDEO else AdUnitFormat.BANNER)
    }
    return formats
}

/** Applies the controls to a Prebid mediation interstitial / rewarded ad unit. */
internal fun FullscreenControls.applyTo(adUnit: MediationBaseFullScreenAdUnit) {
    closeButtonArea?.let { adUnit.setCloseButtonArea(it) }
    closeButtonPosition?.let { adUnit.setCloseButtonPosition(it) }
    skipButtonArea?.let { adUnit.setSkipButtonArea(it) }
    skipButtonPosition?.let { adUnit.setSkipButtonPosition(it) }
    skipDelay?.let { adUnit.setSkipDelay(it) }
    isMuted?.let { adUnit.setIsMuted(it) }
    isSoundButtonVisible?.let { adUnit.setIsSoundButtonVisible(it) }
    if (adUnit is MediationInterstitialAdUnit &&
        minWidthPercentage != null && minHeightPercentage != null
    ) {
        adUnit.setMinSizePercentage(minWidthPercentage, minHeightPercentage)
    }
}

