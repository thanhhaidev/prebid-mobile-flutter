package io.github.thanhhaidev.prebid_mobile_sdk_gam

import java.util.EnumSet
import org.prebid.mobile.ResultCode
import org.prebid.mobile.api.data.AdUnitFormat
import org.prebid.mobile.api.rendering.BaseInterstitialAdUnit

// This package's own helpers; the parsing every companion shares is in
// PrebidRequests.

/** The error messages and codes this plugin reports to Dart. */
internal object PluginErrors {
    const val NOT_INITIALIZED = "The Prebid SDK is not initialized"
    /** [NOT_INITIALIZED] as a result-code name (the native view's reason). */
    const val NOT_INITIALIZED_CODE = "prebidSdkNotInitialized"
    const val NO_ACTIVITY = "No Activity is attached to the Flutter engine"
    const val NOT_LOADED = "The ad is not loaded"
    const val UNKNOWN = "Unknown error"
}

/**
 * Interstitial formats: `adFormats` (`AdFormat` names) when it names any,
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

/** Applies the controls to a Prebid rendering interstitial / rewarded ad unit. */
internal fun FullscreenControls.applyTo(adUnit: BaseInterstitialAdUnit) {
    closeButtonArea?.let { adUnit.setCloseButtonArea(it) }
    closeButtonPosition?.let { adUnit.setCloseButtonPosition(it) }
    skipButtonArea?.let { adUnit.setSkipButtonArea(it) }
    skipButtonPosition?.let { adUnit.setSkipButtonPosition(it) }
    skipDelay?.let { adUnit.setSkipDelay(it) }
    isMuted?.let { adUnit.setIsMuted(it) }
    isSoundButtonVisible?.let { adUnit.setIsSoundButtonVisible(it) }
}

/**
 * Maps an Android [ResultCode] to the result-code names the
 * core prebid_mobile_sdk Dart API uses (the iOS `ResultCode` case names), so
 * both platforms report the same strings.
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
    ResultCode.INVALID_CONTEXT -> "prebidInvalidContext"
    ResultCode.INVALID_AD_OBJECT -> "prebidInvalidAdObject"
    ResultCode.INVALID_NATIVE_REQUEST -> "prebidInvalidNativeRequest"
    ResultCode.INVALID_PREBID_REQUEST_OBJECT -> "prebidInvalidRequest"
}

