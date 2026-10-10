package com.prebid.prebid_mobile_sdk_admob

import org.prebid.mobile.NativeAsset
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeEventTracker
import org.prebid.mobile.NativeImageAsset
import org.prebid.mobile.NativeTitleAsset
import org.prebid.mobile.api.data.Position
import org.prebid.mobile.rendering.bidding.display.BidResponseCache

// Helpers for the values the Dart side sends over method channels:
// `NativeAsset.toMap()`, `NativeEventTracker.toMap()`,
// `PrebidFullscreenControls.toMap()` and `VideoParameters.toMap()` from
// prebid_mobile_sdk.

private fun Map<*, *>.int(key: String): Int? = (this[key] as? Number)?.toInt()

/// Native request assets, or null when the widget uses the defaults.
internal fun nativeAssetsFrom(raw: Any?): List<NativeAsset>? {
    val list = raw as? List<*> ?: return null
    return list.mapNotNull { item ->
        val m = item as? Map<*, *> ?: return@mapNotNull null
        val required = m["required"] as? Boolean ?: false
        when (m["assetType"]) {
            "title" -> NativeTitleAsset().apply {
                setLength(m.int("titleLength") ?: 90)
                isRequired = required
            }
            "image" -> NativeImageAsset(
                m.int("imageWidthMin") ?: 0,
                m.int("imageHeightMin") ?: 0,
                m.int("imageWidth") ?: 0,
                m.int("imageHeight") ?: 0,
            ).apply {
                val type = m.int("imageType")
                imageType = NativeImageAsset.IMAGE_TYPE.values().firstOrNull { it.id == type }
                isRequired = required
            }
            "data" -> NativeDataAsset().apply {
                val type = m.int("dataType")
                dataType = NativeDataAsset.DATA_TYPE.values().firstOrNull { it.id == type }
                m.int("dataLength")?.let { len = it }
                isRequired = required
            }
            else -> null
        }
    }
}

/// Native event trackers, or null when the widget uses the defaults.
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
    }
}

/// `maxDuration` from `VideoParameters.toMap()`. Prebid Android's mediation
/// interstitial / rewarded ad units only expose `setMaxVideoDuration`, so it is
/// the one video parameter applied on Android (the full set applies on iOS).
internal fun videoMaxDurationFrom(raw: Any?): Int? = (raw as? Map<*, *>)?.int("maxDuration")

/// `debugDropBidProbability` (`PrebidAdMob.debugDropBidProbability`, testing
/// only), clamped to `0..1`; 0 when absent.
internal fun debugDropBidProbability(raw: Any?): Double =
    ((raw as? Number)?.toDouble() ?: 0.0).takeIf { !it.isNaN() }?.coerceIn(0.0, 1.0) ?: 0.0

/// Testing hook: with [probability], pops the Prebid bid whose response id the
/// mediation utils stored in [extras] under [responseIdKey] (the adapter's
/// `EXTRA_RESPONSE_ID`) from [BidResponseCache] — exactly what Prebid's
/// internal test app "Random" screens do — so the Prebid adapter finds no bid
/// and AdMob falls back to its waterfall. Call after `fetchDemand` completes.
internal fun maybeDropBid(probability: Double, extras: android.os.Bundle, responseIdKey: String) {
    if (probability <= 0.0 || kotlin.random.Random.nextDouble() >= probability) return
    extras.getString(responseIdKey)?.let { BidResponseCache.getInstance().popBidResponse(it) }
}

/// Interstitial formats: `adFormats` (`AdFormat` names) when it names any,
/// else video or banner from `isVideo`.
internal fun adUnitFormats(raw: Any?, isVideo: Boolean): java.util.EnumSet<org.prebid.mobile.api.data.AdUnitFormat> {
    val names = (raw as? List<*>).orEmpty().filterIsInstance<String>()
    val formats = java.util.EnumSet.noneOf(org.prebid.mobile.api.data.AdUnitFormat::class.java)
    if ("banner" in names) formats.add(org.prebid.mobile.api.data.AdUnitFormat.BANNER)
    if ("video" in names) formats.add(org.prebid.mobile.api.data.AdUnitFormat.VIDEO)
    if (formats.isEmpty()) {
        formats.add(if (isVideo) org.prebid.mobile.api.data.AdUnitFormat.VIDEO else org.prebid.mobile.api.data.AdUnitFormat.BANNER)
    }
    return formats
}

/// Fullscreen rendering controls (`PrebidFullscreenControls`).
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

/// Applies the controls to a Prebid mediation interstitial / rewarded ad unit.
internal fun FullscreenControls.applyTo(adUnit: org.prebid.mobile.api.mediation.MediationBaseFullScreenAdUnit) {
    closeButtonArea?.let { adUnit.setCloseButtonArea(it) }
    closeButtonPosition?.let { adUnit.setCloseButtonPosition(it) }
    skipButtonArea?.let { adUnit.setSkipButtonArea(it) }
    skipButtonPosition?.let { adUnit.setSkipButtonPosition(it) }
    skipDelay?.let { adUnit.setSkipDelay(it) }
    isMuted?.let { adUnit.setIsMuted(it) }
    isSoundButtonVisible?.let { adUnit.setIsSoundButtonVisible(it) }
    if (adUnit is org.prebid.mobile.api.mediation.MediationInterstitialAdUnit &&
        minWidthPercentage != null && minHeightPercentage != null
    ) {
        adUnit.setMinSizePercentage(minWidthPercentage, minHeightPercentage)
    }
}

/// Native context / context subtype / placement type from the Dart payload,
/// overriding the view's defaults when set.
internal class NativeContext(
    val context: org.prebid.mobile.NativeAdUnit.CONTEXT_TYPE?,
    val subType: org.prebid.mobile.NativeAdUnit.CONTEXTSUBTYPE?,
    val placement: org.prebid.mobile.NativeAdUnit.PLACEMENTTYPE?,
) {
    companion object {
        fun from(params: Map<*, *>): NativeContext {
            fun id(key: String) = (params[key] as? Number)?.toInt()
            return NativeContext(
                id("context")?.let { v -> org.prebid.mobile.NativeAdUnit.CONTEXT_TYPE.values().firstOrNull { it.id == v } },
                id("contextSubType")?.let { v -> org.prebid.mobile.NativeAdUnit.CONTEXTSUBTYPE.values().firstOrNull { it.id == v } },
                id("placementType")?.let { v -> org.prebid.mobile.NativeAdUnit.PLACEMENTTYPE.values().firstOrNull { it.id == v } },
            )
        }
    }
}
