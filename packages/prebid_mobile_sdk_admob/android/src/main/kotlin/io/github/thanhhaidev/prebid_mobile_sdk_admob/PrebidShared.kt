package io.github.thanhhaidev.prebid_mobile_sdk_admob

import android.os.Bundle
import java.util.EnumSet
import kotlin.random.Random
import org.json.JSONObject
import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.NativeAsset
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeEventTracker
import org.prebid.mobile.NativeImageAsset
import org.prebid.mobile.NativeTitleAsset
import org.prebid.mobile.api.data.AdUnitFormat
import org.prebid.mobile.api.data.Position
import org.prebid.mobile.api.mediation.MediationBaseFullScreenAdUnit
import org.prebid.mobile.api.mediation.MediationInterstitialAdUnit
import org.prebid.mobile.api.mediation.MediationNativeAdUnit
import org.prebid.mobile.rendering.bidding.display.BidResponseCache

// Helpers for the values the Dart side sends over method channels:
// `NativeAsset.toMap()`, `NativeEventTracker.toMap()`,
// `PrebidFullscreenControls.toMap()` and `VideoParameters.toMap()` from
// prebid_mobile_sdk.

private fun Map<*, *>.int(key: String): Int? = (this[key] as? Number)?.toInt()

/** A JSON object string (`jsonEncode` in Dart) as a [JSONObject], or null. */
private fun Map<*, *>.json(key: String): JSONObject? =
    (this[key] as? String)?.let { runCatching { JSONObject(it) }.getOrNull() }

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

/** Native request assets, or null when the widget uses the defaults. */
internal fun nativeAssetsFrom(raw: Any?): List<NativeAsset>? {
    val list = raw as? List<*> ?: return null
    return list.mapNotNull { item ->
        val m = item as? Map<*, *> ?: return@mapNotNull null
        val required = m["required"] as? Boolean ?: false
        when (m["assetType"]) {
            "title" -> NativeTitleAsset().apply {
                setLength(m.int("titleLength") ?: 90)
                isRequired = required
                m.json("ext")?.let(::setTitleExt)
                m.json("assetExt")?.let(::setAssetExt)
            }
            "image" -> NativeImageAsset(
                m.int("imageWidthMin") ?: 0,
                m.int("imageHeightMin") ?: 0,
                m.int("imageWidth") ?: 0,
                m.int("imageHeight") ?: 0,
            ).apply {
                val type = m.int("imageType")
                imageType = NativeImageAsset.IMAGE_TYPE.values().firstOrNull { it.id == type }
                (m["imageMimes"] as? List<*>)?.filterIsInstance<String>()?.forEach(::addMime)
                isRequired = required
                m.json("ext")?.let(::setImageExt)
                m.json("assetExt")?.let(::setAssetExt)
            }
            "data" -> NativeDataAsset().apply {
                val type = m.int("dataType")
                dataType = NativeDataAsset.DATA_TYPE.values().firstOrNull { it.id == type }
                m.int("dataLength")?.let { len = it }
                isRequired = required
                m.json("ext")?.let(::setDataExt)
                m.json("assetExt")?.let(::setAssetExt)
            }
            else -> null
        }
    }
}

/** Native event trackers, or null when the widget uses the defaults. */
internal fun nativeTrackersFrom(raw: Any?): List<NativeEventTracker>? {
    val list = raw as? List<*> ?: return null
    return list.mapNotNull { item ->
        val m = item as? Map<*, *> ?: return@mapNotNull null
        val eventType = m.int("eventType")
        val type = NativeEventTracker.EVENT_TYPE.values().firstOrNull { it.id == eventType }
            ?: return@mapNotNull null
        val methods = (m["methods"] as? List<*>).orEmpty().mapNotNull { v ->
            val id = (v as? Number)?.toInt()
            NativeEventTracker.EVENT_TRACKING_METHOD.values().firstOrNull { it.id == id }
        }
        runCatching { NativeEventTracker(type, ArrayList(methods)) }.getOrNull()
            ?.apply { m.json("ext")?.let(::setExt) }
    }
}

/**
 * `maxDuration` from `VideoParameters.toMap()`. Prebid Android's mediation
 * interstitial / rewarded ad units only expose `setMaxVideoDuration`, so it is
 * the one video parameter applied on Android (the full set applies on iOS).
 */
internal fun videoMaxDurationFrom(raw: Any?): Int? = (raw as? Map<*, *>)?.int("maxDuration")

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

/** Fullscreen rendering controls (`PrebidFullscreenControls`). */
internal class FullscreenControls(m: Map<*, *>) {
    val closeButtonArea = (m["closeButtonArea"] as? Number)?.toDouble()
    val closeButtonPosition = position(m["closeButtonPosition"])
    val skipButtonArea = (m["skipButtonArea"] as? Number)?.toDouble()
    val skipButtonPosition = position(m["skipButtonPosition"])
    val skipDelay = m.int("skipDelay")
    val isMuted = m["isMuted"] as? Boolean
    val isSoundButtonVisible = m["isSoundButtonVisible"] as? Boolean
    val minWidthPercentage = m.int("minWidthPercentage")
    val minHeightPercentage = m.int("minHeightPercentage")
    // `supportSKOverlay` is iOS only, and has no mediation equivalent; ignored.

    companion object {
        fun from(raw: Any?): FullscreenControls? = (raw as? Map<*, *>)?.let { FullscreenControls(it) }

        private fun position(raw: Any?): Position? = when (raw) {
            "topLeft" -> Position.TOP_LEFT
            "topRight" -> Position.TOP_RIGHT
            else -> null
        }
    }
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

/**
 * Native context / context subtype / placement type from the Dart payload,
 * overriding the view's defaults when set.
 */
internal class NativeContext(
    val context: NativeAdUnit.CONTEXT_TYPE?,
    val subType: NativeAdUnit.CONTEXTSUBTYPE?,
    val placement: NativeAdUnit.PLACEMENTTYPE?,
) {
    companion object {
        fun from(params: Map<*, *>): NativeContext {
            fun id(key: String) = (params[key] as? Number)?.toInt()
            return NativeContext(
                id("context")?.let { v -> NativeAdUnit.CONTEXT_TYPE.values().firstOrNull { it.id == v } },
                id("contextSubType")?.let { v -> NativeAdUnit.CONTEXTSUBTYPE.values().firstOrNull { it.id == v } },
                id("placementType")?.let { v -> NativeAdUnit.PLACEMENTTYPE.values().firstOrNull { it.id == v } },
            )
        }
    }
}

/** The native request options of a native widget (`seq`, URL support, privacy, `ext`…). */
internal class NativeRequestOptions(params: Map<*, *>) {
    private val placementCount = params.int("placementCount")
    private val sequence = params.int("sequence")
    private val assetUrlSupport = params["assetUrlSupport"] as? Boolean
    private val dUrlSupport = params["dUrlSupport"] as? Boolean
    private val privacy = params["privacy"] as? Boolean
    private val ext = params.json("ext")

    fun applyTo(unit: MediationNativeAdUnit) {
        placementCount?.let(unit::setPlacementCount)
        sequence?.let(unit::setSeq)
        assetUrlSupport?.let(unit::setAUrlSupport)
        dUrlSupport?.let(unit::setDUrlSupport)
        privacy?.let(unit::setPrivacy)
        ext?.let(unit::setExt)
    }
}
