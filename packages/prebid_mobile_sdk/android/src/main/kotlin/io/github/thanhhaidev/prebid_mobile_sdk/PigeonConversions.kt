package io.github.thanhhaidev.prebid_mobile_sdk

import org.json.JSONArray
import org.json.JSONObject
import org.prebid.mobile.AdSize
import org.prebid.mobile.NativeAdUnit
import org.prebid.mobile.NativeAsset
import org.prebid.mobile.NativeDataAsset
import org.prebid.mobile.NativeEventTracker
import org.prebid.mobile.NativeImageAsset
import org.prebid.mobile.NativeParameters
import org.prebid.mobile.NativeTitleAsset
import org.prebid.mobile.PrebidNativeAd
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
    if (width != null && height != null) vp.adSize = AdSize(width.toInt(), height.toInt())
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

/** A Prebid native asset for the request, or null for an unknown type. */
internal fun NativeAssetConfig.toPrebidAsset(): NativeAsset? = when (assetType) {
    "title" -> NativeTitleAsset().apply {
        setLength(titleLength?.toInt() ?: 90)
        isRequired = required_
        jsonObject(this@toPrebidAsset.ext)?.let(::setTitleExt)
        jsonObject(this@toPrebidAsset.assetExt)?.let(::setAssetExt)
    }
    "image" -> NativeImageAsset(
        imageWidthMin?.toInt() ?: 0,
        imageHeightMin?.toInt() ?: 0,
        imageWidth?.toInt() ?: 0,
        imageHeight?.toInt() ?: 0,
    ).apply {
        imageType = NativeImageAsset.IMAGE_TYPE.values().firstOrNull { it.id.toLong() == this@toPrebidAsset.imageType }
        imageMimes?.filterNotNull()?.forEach(::addMime)
        isRequired = required_
        jsonObject(this@toPrebidAsset.ext)?.let(::setImageExt)
        jsonObject(this@toPrebidAsset.assetExt)?.let(::setAssetExt)
    }
    "data" -> NativeDataAsset().apply {
        dataType = NativeDataAsset.DATA_TYPE.values().firstOrNull { it.id.toLong() == this@toPrebidAsset.dataType }
        dataLength?.let { setLen(it.toInt()) }
        isRequired = required_
        jsonObject(this@toPrebidAsset.ext)?.let(::setDataExt)
        jsonObject(this@toPrebidAsset.assetExt)?.let(::setAssetExt)
    }
    else -> null
}

/** A Prebid native event tracker, or null for an unknown event type. */
internal fun NativeEventTrackerConfig.toPrebidTracker(): NativeEventTracker? {
    val type = NativeEventTracker.EVENT_TYPE.values().firstOrNull { it.id.toLong() == eventType }
        ?: return null
    val trackingMethods = methods.mapNotNull { id ->
        NativeEventTracker.EVENT_TRACKING_METHOD.values().firstOrNull { it.id.toLong() == id }
    }
    return NativeEventTracker(type, ArrayList(trackingMethods)).apply {
        jsonObject(this@toPrebidTracker.ext)?.let(::setExt)
    }
}

/** A JSON object string from Dart as a [JSONObject], or null when invalid. */
internal fun jsonObject(json: String?): JSONObject? =
    json?.let { runCatching { JSONObject(it) }.getOrNull() }

/**
 * The native request settings of a [NativeAdRequestConfig], applied to an
 * In-App [NativeAdUnit] or an Original API [NativeParameters] (two Prebid
 * types with the same setters and no common interface).
 */
internal class NativeRequestSettings(private val config: NativeAdRequestConfig) {
    private val assets = config.assets.orEmpty().mapNotNull { it?.toPrebidAsset() }
    private val trackers = config.eventTrackers.orEmpty().mapNotNull { it?.toPrebidTracker() }
    private val context = NativeAdUnit.CONTEXT_TYPE.values().firstOrNull { it.id.toLong() == config.context }
    private val contextSubType =
        NativeAdUnit.CONTEXTSUBTYPE.values().firstOrNull { it.id.toLong() == config.contextSubType }
    private val placementType =
        NativeAdUnit.PLACEMENTTYPE.values().firstOrNull { it.id.toLong() == config.placementType }
    private val ext = jsonObject(config.ext)

    fun applyTo(unit: NativeAdUnit) {
        assets.forEach(unit::addAsset)
        trackers.forEach(unit::addEventTracker)
        context?.let(unit::setContextType)
        contextSubType?.let(unit::setContextSubType)
        placementType?.let(unit::setPlacementType)
        config.placementCount?.let { unit.setPlacementCount(it.toInt()) }
        config.sequence?.let { unit.setSeq(it.toInt()) }
        config.assetUrlSupport?.let(unit::setAUrlSupport)
        config.dUrlSupport?.let(unit::setDUrlSupport)
        config.privacy?.let(unit::setPrivacy)
        ext?.let(unit::setExt)
        config.pbAdSlot?.let(unit::setPbAdSlot)
        config.gpid?.let(unit::setGpid)
        config.impOrtbConfig?.let(unit::setImpOrtbConfig)
        config.globalOrtbConfig?.let(unit::setGlobalOrtbConfig)
    }

    fun toParameters(): NativeParameters = NativeParameters(assets).apply {
        trackers.forEach(::addEventTracker)
        context?.let(::setContextType)
        contextSubType?.let(::setContextSubType)
        placementType?.let(::setPlacementType)
        config.placementCount?.let { setPlacementCount(it.toInt()) }
        config.sequence?.let { setSeq(it.toInt()) }
        config.assetUrlSupport?.let(::setAUrlSupport)
        config.dUrlSupport?.let(::setDUrlSupport)
        config.privacy?.let(::setPrivacy)
        ext?.let(::setExt)
    }
}

/** The assets of a loaded native ad, as sent to Dart. */
internal fun PrebidNativeAd.toNativeAdData() = NativeAdData(
    title = title,
    text = description,
    iconUrl = iconUrl,
    imageUrl = imageUrl,
    sponsoredBy = sponsoredBy,
    callToAction = callToAction,
    clickUrl = clickUrl,
    privacyUrl = privacyUrl,
    titles = titles.map { it.text },
    images = images.map { NativeAdImageData(type = it.typeNumber.toLong(), url = it.url) },
    dataAssets = dataList.map { NativeAdDataAssetData(type = it.typeNumber.toLong(), value = it.value) },
)

/** The Original API result of a fetchDemand [BidInfo]. */
internal fun BidInfo.toMultiformatResult() = MultiformatBidResult(
    resultCode = dartResultCode(),
    winningFormat = targetingKeywords?.get("hb_format"),
    targetingKeywords = targetingKeywords?.mapKeys { it.key } ?: emptyMap(),
    nativeAdCacheId = nativeCacheId,
    exp = exp?.toDouble(),
    topBidFiltered = isTopBidFiltered,
    events = events?.takeIf { it.isNotEmpty() },
)
