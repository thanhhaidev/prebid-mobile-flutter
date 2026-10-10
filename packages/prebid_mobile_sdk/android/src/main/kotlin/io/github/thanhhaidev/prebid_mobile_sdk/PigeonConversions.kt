package io.github.thanhhaidev.prebid_mobile_sdk

import org.json.JSONArray
import org.json.JSONObject
import org.prebid.mobile.ResultCode
import org.prebid.mobile.Signals
import org.prebid.mobile.VideoParameters
import org.prebid.mobile.api.data.BidInfo
import org.prebid.mobile.api.data.Position
import org.prebid.mobile.api.rendering.BaseInterstitialAdUnit

// Ad events sent to Dart, and conversions between Pigeon types and the Prebid SDK.

/** Errors reported to Dart as onAdFailed / result codes. */
internal object PluginErrors {
    const val NO_ACTIVITY = "No Activity is attached to the Flutter engine"
    const val NOT_READY = "The ad is not loaded"
    const val NOT_INITIALIZED = "The Prebid SDK is not initialized"

    /**
     * Result code when a fetch runs before the SDK has initialized:
     * Prebid Android then drops the request without calling back.
     */
    const val NOT_INITIALIZED_CODE = "prebidSdkNotInitialized"
}

internal fun AdFlutterApi.sendAdFailed(adId: Long, error: String) {
    onAdEvent(AdEvent(adId = adId, eventName = "onAdFailed", error = error)) {}
}

/**
 * Maps an Android [ResultCode] to the result-code names the
 * Dart API uses (the iOS `ResultCode` case names), so both platforms report
 * the same strings and `isSuccess` works everywhere.
 */
internal fun ResultCode.toDartCode(): String = when (this) {
    ResultCode.SUCCESS -> "prebidDemandFetchSuccess"
    ResultCode.INVALID_ACCOUNT_ID -> "prebidInvalidAccountId"
    ResultCode.INVALID_CONFIG_ID -> "prebidInvalidConfigId"
    ResultCode.INVALID_SIZE -> "prebidInvalidSize"
    ResultCode.INVALID_HOST_URL -> "prebidServerURLInvalid"
    ResultCode.NETWORK_ERROR -> "prebidNetworkError"
    ResultCode.PREBID_SERVER_ERROR -> "prebidServerError"
    ResultCode.NO_BIDS -> "prebidDemandNoBids"
    ResultCode.NO_CACHED_BIDS -> "prebidDemandNoCachedBids"
    ResultCode.TIMEOUT -> "prebidDemandTimedOut"
    else -> "prebidInvalidRequest"
}

/**
 * Result code for a fetchDemand [BidInfo].
 * Prebid Android's Original API reports SUCCESS even for an empty seatbid
 * (no winning bid); iOS reports no-bids. Treat SUCCESS without targeting
 * keywords as no-bids so both platforms agree.
 */
internal fun BidInfo.dartResultCode(): String =
    if (resultCode == ResultCode.SUCCESS && targetingKeywords.isNullOrEmpty()) {
        "prebidDemandNoBids"
    } else {
        resultCode.toDartCode()
    }

/** Builds Prebid video parameters from the Pigeon config. */
internal fun VideoParametersConfig.toVideoParameters(): VideoParameters {
    val vp = VideoParameters(mimes)
    protocols?.filterNotNull()?.let { list ->
        vp.protocols = list.map { Signals.Protocols(it.toInt()) }
    }
    playbackMethods?.filterNotNull()?.let { list ->
        vp.playbackMethod = list.map { Signals.PlaybackMethod(it.toInt()) }
    }
    placement?.let { vp.placement = Signals.Placement(it.toInt()) }
    plcmt?.let { vp.plcmt = Signals.Plcmt(it.toInt()) }
    api?.filterNotNull()?.let { list ->
        vp.api = list.map { Signals.Api(it.toInt()) }
    }
    maxDuration?.let { vp.maxDuration = it.toInt() }
    minDuration?.let { vp.minDuration = it.toInt() }
    startDelay?.let { vp.startDelay = Signals.StartDelay(it.toInt()) }
    linearity?.let { vp.linearity = it.toInt() }
    skippable?.let { vp.skippable = it }
    battr?.filterNotNull()?.let { list ->
        vp.battr = list.map { Signals.CreativeAttribute(it.toInt()) }
    }
    minBitrate?.let { vp.minBitrate = it.toInt() }
    maxBitrate?.let { vp.maxBitrate = it.toInt() }
    return vp
}

/** Applies fullscreen controls to a rendering interstitial / rewarded ad unit. */
internal fun FullscreenControlsConfig.applyTo(adUnit: BaseInterstitialAdUnit) {
    closeButtonArea?.let { adUnit.setCloseButtonArea(it) }
    closeButtonPosition?.toPrebidPosition()?.let { adUnit.setCloseButtonPosition(it) }
    skipButtonArea?.let { adUnit.setSkipButtonArea(it) }
    skipButtonPosition?.toPrebidPosition()?.let { adUnit.setSkipButtonPosition(it) }
    skipDelay?.let { adUnit.setSkipDelay(it.toInt()) }
    isMuted?.let { adUnit.setIsMuted(it) }
    isSoundButtonVisible?.let { adUnit.setIsSoundButtonVisible(it) }
    // isAutoCloseOnCompletionEnabled, supportSKOverlay: iOS only.
}

internal fun String.toPrebidPosition(): Position? = when (this) {
    "topLeft" -> Position.TOP_LEFT
    "topRight" -> Position.TOP_RIGHT
    else -> null
}

/** JSONObject -> Map for the Pigeon codec (nested objects / arrays included). */
internal fun JSONObject.toMap(): Map<String?, Any?> =
    keys().asSequence().associateWith { key -> opt(key).toPigeonValue() }

private fun Any?.toPigeonValue(): Any? = when (this) {
    JSONObject.NULL, null -> null
    is JSONObject -> toMap()
    is JSONArray -> (0 until length()).map { opt(it).toPigeonValue() }
    else -> this
}
