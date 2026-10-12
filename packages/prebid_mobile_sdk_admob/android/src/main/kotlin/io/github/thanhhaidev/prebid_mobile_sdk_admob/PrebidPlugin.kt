package io.github.thanhhaidev.prebid_mobile_sdk_admob

import android.content.Context
import android.view.View
import java.util.EnumSet
import kotlin.math.roundToInt
import kotlin.random.Random
import org.prebid.mobile.api.data.AdUnitFormat

// Shared by the companion packages; tool/check_copies.sh keeps the copies
// identical. The request parsing is in PrebidRequests, each package's own
// helpers in PrebidShared.

/** The error messages and codes the companion plugins report to Dart. */
internal object PluginErrors {
    const val NOT_INITIALIZED = "The Prebid SDK is not initialized"

    /** [NOT_INITIALIZED] as a result-code name (a native view's reason). */
    const val NOT_INITIALIZED_CODE = "prebidSdkNotInitialized"
    const val NO_ACTIVITY = "No Activity is attached to the Flutter engine"
    const val NOT_LOADED = "The ad is not loaded"
    const val ACTIVITY_DESTROYED = "The Activity was destroyed"
    const val ACTIVITY_RECREATED = "The Activity was re-created for a configuration change"
    const val UNKNOWN = "Unknown error"
}

/** An SDK error message for Dart; null or blank becomes [PluginErrors.UNKNOWN]. */
internal fun errorMessage(message: String?): String = message?.takeIf { it.isNotBlank() } ?: PluginErrors.UNKNOWN

/**
 * The payload of a native view's failure event (`onAdFailed`,
 * `primaryAdFailed`, ...): `{error: message}`, as the fullscreen ads send.
 */
internal fun failure(message: String?): Map<String, Any?> = mapOf("error" to errorMessage(message))

/**
 * The method channel name of a platform view: `<prefix>_<channelId>`, the id
 * the Dart widget listens on before the view exists (so a failure reported
 * during creation is not lost). Falls back to the platform view id.
 */
internal fun viewChannelName(prefix: String, params: Map<*, *>, viewId: Int): String =
    "${prefix}_${(params["channelId"] as? Number)?.toLong() ?: viewId.toLong()}"

/** [value] dp in pixels. */
internal fun Context.dp(value: Int): Int = (value * resources.displayMetrics.density).roundToInt()

/**
 * [content]'s natural height at [width] pixels, in logical pixels: a
 * platform view is clamped to its Flutter-side size, so its own height
 * would only echo that.
 */
internal fun naturalHeight(content: View, width: Int): Double {
    content.measure(
        View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    return (content.measuredHeight / content.resources.displayMetrics.density).toDouble()
}

/**
 * `debugDropBidProbability` (`PrebidAdMob` / `PrebidMax`
 * `.debugDropBidProbability`, testing only), clamped to `0..1`; 0 when absent.
 */
internal fun debugDropBidProbability(raw: Any?): Double =
    ((raw as? Number)?.toDouble() ?: 0.0).takeIf { !it.isNaN() }?.coerceIn(0.0, 1.0) ?: 0.0

/** Testing hook: whether to withhold this load's Prebid bid, with [probability]. */
internal fun shouldDropBid(probability: Double): Boolean = probability > 0.0 && Random.nextDouble() < probability

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
