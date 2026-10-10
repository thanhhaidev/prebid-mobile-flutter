package io.github.thanhhaidev.prebid_mobile_sdk_gam

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
