package io.github.thanhhaidev.prebid_mobile_sdk_max

import com.applovin.mediation.MaxAd
import java.util.EnumSet
import kotlin.random.Random
import org.prebid.mobile.api.data.AdUnitFormat
import org.prebid.mobile.api.mediation.MediationBaseFullScreenAdUnit
import org.prebid.mobile.api.mediation.MediationInterstitialAdUnit

// This package's own helpers; the parsing every companion shares is in
// PrebidRequests.

/**
 * `debugDropBidProbability` (`PrebidMax.debugDropBidProbability`, testing
 * only), clamped to `0..1`; 0 when absent.
 */
internal fun debugDropBidProbability(raw: Any?): Double =
    ((raw as? Number)?.toDouble() ?: 0.0).takeIf { !it.isNaN() }?.coerceIn(0.0, 1.0) ?: 0.0

/**
 * Testing hook: whether to withhold this load's Prebid bid from MAX, with
 * [probability]. The caller then sets the MAX local extra
 * `PrebidMaxMediationAdapter.EXTRA_RESPONSE_ID` to `""` — exactly what
 * Prebid's internal test app "Random" screens do — so the Prebid adapter
 * finds no bid and MAX falls back to its waterfall.
 */
internal fun shouldDropBid(probability: Double): Boolean =
    probability > 0.0 && Random.nextDouble() < probability

/** The `onAdRevenuePaid` payload (`PrebidMaxAdRevenue` on the Dart side). */
internal fun revenuePayload(ad: MaxAd): Map<String, Any?> = mapOf(
    "revenue" to ad.revenue,
    "revenuePrecision" to ad.revenuePrecision,
    "networkName" to ad.networkName,
    "placement" to ad.placement,
)

/** `adFormats` (`PrebidAdFormat` names), or null when it names none. */
internal fun adUnitFormatsFrom(raw: Any?): EnumSet<AdUnitFormat>? {
    val names = (raw as? List<*>).orEmpty().filterIsInstance<String>()
    val formats = EnumSet.noneOf(AdUnitFormat::class.java)
    if ("banner" in names) formats.add(AdUnitFormat.BANNER)
    if ("video" in names) formats.add(AdUnitFormat.VIDEO)
    return formats.takeIf { it.isNotEmpty() }
}

/**
 * Interstitial formats: `adFormats` when it names any, else video or banner
 * from `isVideo`.
 */
internal fun adUnitFormats(raw: Any?, isVideo: Boolean): EnumSet<AdUnitFormat> =
    adUnitFormatsFrom(raw) ?: EnumSet.of(if (isVideo) AdUnitFormat.VIDEO else AdUnitFormat.BANNER)

/** Sent when an SDK reports a failure without a message. */
internal const val UNKNOWN_ERROR = "Unknown error"

/** [message], or [UNKNOWN_ERROR] when it is null or empty. */
internal fun errorMessage(message: String?): String =
    message?.takeIf { it.isNotEmpty() } ?: UNKNOWN_ERROR

/**
 * The method channel name of a platform view: `<prefix>_<channelId>`, the id
 * the Dart widget listens on before the view exists (so a failure reported
 * during creation is not lost). Falls back to the platform view id.
 */
internal fun viewChannelName(prefix: String, params: Map<*, *>, viewId: Int): String =
    "${prefix}_${(params["channelId"] as? Number)?.toLong() ?: viewId.toLong()}"

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

