package io.github.thanhhaidev.prebid_mobile_sdk_max

import com.applovin.mediation.MaxAd
import org.prebid.mobile.api.mediation.MediationBaseFullScreenAdUnit
import org.prebid.mobile.api.mediation.MediationInterstitialAdUnit

// This package's own helpers; what every companion shares is in
// PrebidPlugin and PrebidRequests.

/** The `onAdRevenuePaid` payload (`PrebidMaxAdRevenue` on the Dart side). */
internal fun revenuePayload(ad: MaxAd): Map<String, Any?> = mapOf(
    "revenue" to ad.revenue,
    "revenuePrecision" to ad.revenuePrecision,
    "networkName" to ad.networkName,
    "placement" to ad.placement,
)

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

