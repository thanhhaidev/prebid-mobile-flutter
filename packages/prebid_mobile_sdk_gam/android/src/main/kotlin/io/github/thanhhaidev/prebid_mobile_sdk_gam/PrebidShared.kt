package io.github.thanhhaidev.prebid_mobile_sdk_gam

import org.prebid.mobile.ResultCode
import org.prebid.mobile.api.rendering.BaseInterstitialAdUnit

// This package's own helpers; what every companion shares is in
// PrebidPlugin and PrebidRequests.

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

