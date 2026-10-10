package io.github.thanhhaidev.prebid_mobile_sdk_admob

import android.os.Bundle
import org.prebid.mobile.api.mediation.MediationBaseFullScreenAdUnit
import org.prebid.mobile.api.mediation.MediationInterstitialAdUnit
import org.prebid.mobile.rendering.bidding.display.BidResponseCache

// This package's own helpers; what every companion shares is in
// PrebidPlugin and PrebidRequests.

/**
 * Testing hook: with [probability], pops the Prebid bid whose response id the
 * mediation utils stored in [extras] under [responseIdKey] (the adapter's
 * `EXTRA_RESPONSE_ID`) from [BidResponseCache] — exactly what Prebid's
 * internal test app "Random" screens do — so the Prebid adapter finds no bid
 * and AdMob falls back to its waterfall. Call after `fetchDemand` completes.
 */
internal fun maybeDropBid(probability: Double, extras: Bundle, responseIdKey: String) {
    if (!shouldDropBid(probability)) return
    extras.getString(responseIdKey)?.let { BidResponseCache.getInstance().popBidResponse(it) }
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

