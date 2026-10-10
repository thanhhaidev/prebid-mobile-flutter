package io.github.thanhhaidev.prebid_mobile_sdk_admob

import org.json.JSONObject
import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.NativeAsset
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeEventTracker
import org.prebid.mobile.NativeImageAsset
import org.prebid.mobile.NativeTitleAsset
import org.prebid.mobile.api.data.Position
import org.prebid.mobile.api.mediation.MediationNativeAdUnit

// Parsing of the values the Dart side sends over method channels
// (`NativeParameters.toMap()`, `PrebidFullscreenControls.toMap()`,
// `VideoParameters.toMap()`), the same in every companion package:
// tool/check_copies.sh keeps the three copies identical apart from the
// package line.

internal fun Map<*, *>.int(key: String): Int? = (this[key] as? Number)?.toInt()

/** A JSON object string (`jsonEncode` in Dart) as a [JSONObject], or null. */
internal fun Map<*, *>.json(key: String): JSONObject? =
    (this[key] as? String)?.let { runCatching { JSONObject(it) }.getOrNull() }

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
            // Prebid's argument order: w, h, wmin, hmin.
            "image" -> NativeImageAsset(
                m.int("imageWidth") ?: 0,
                m.int("imageHeight") ?: 0,
                m.int("imageWidthMin") ?: 0,
                m.int("imageHeightMin") ?: 0,
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
 * `maxDuration` from `VideoParameters.toMap()`. Prebid Android's rendering and mediation
 * interstitial / rewarded ad units only expose `setMaxVideoDuration`, so it is
 * the one video parameter applied on Android (the full set applies on iOS).
 */
internal fun videoMaxDurationFrom(raw: Any?): Int? = (raw as? Map<*, *>)?.int("maxDuration")

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
    // `supportSKOverlay` is iOS only (SKAdNetwork); ignored here.

    companion object {
        fun from(raw: Any?): FullscreenControls? = (raw as? Map<*, *>)?.let { FullscreenControls(it) }

        private fun position(raw: Any?): Position? = when (raw) {
            "topLeft" -> Position.TOP_LEFT
            "topRight" -> Position.TOP_RIGHT
            else -> null
        }
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

    fun applyTo(unit: NativeAdUnit) {
        placementCount?.let(unit::setPlacementCount)
        sequence?.let(unit::setSeq)
        assetUrlSupport?.let(unit::setAUrlSupport)
        dUrlSupport?.let(unit::setDUrlSupport)
        privacy?.let(unit::setPrivacy)
        ext?.let(unit::setExt)
    }

    // MediationNativeAdUnit has the same setters, without a common type.
    fun applyTo(unit: MediationNativeAdUnit) {
        placementCount?.let(unit::setPlacementCount)
        sequence?.let(unit::setSeq)
        assetUrlSupport?.let(unit::setAUrlSupport)
        dUrlSupport?.let(unit::setDUrlSupport)
        privacy?.let(unit::setPrivacy)
        ext?.let(unit::setExt)
    }
}
