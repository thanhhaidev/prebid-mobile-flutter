import Foundation
import CoreGraphics
import UIKit
import PrebidMobile

// This package's own helpers; what every companion shares is in
// PrebidPlugin and PrebidRequests.

extension FullscreenControls {
    func apply(to adUnit: InterstitialRenderingAdUnit) {
        if let v = closeButtonArea { adUnit.closeButtonArea = v }
        if let v = closeButtonPosition { adUnit.closeButtonPosition = v }
        if let v = skipButtonArea { adUnit.skipButtonArea = v }
        if let v = skipButtonPosition { adUnit.skipButtonPosition = v }
        if let v = skipDelay { adUnit.skipDelay = v }
        if let v = isMuted { adUnit.isMuted = v }
        if let v = isSoundButtonVisible { adUnit.isSoundButtonVisible = v }
        if let v = isAutoCloseOnCompletionEnabled { adUnit.isAutoCloseOnCompletionEnabled = v }
        if let v = supportSKOverlay { adUnit.supportSKOverlay = v }
    }

    // Prebid iOS rewarded has no skip-button controls.
    func apply(to adUnit: RewardedAdUnit) {
        if let v = closeButtonArea { adUnit.closeButtonArea = v }
        if let v = closeButtonPosition { adUnit.closeButtonPosition = v }
        if let v = isMuted { adUnit.isMuted = v }
        if let v = isSoundButtonVisible { adUnit.isSoundButtonVisible = v }
        if let v = supportSKOverlay { adUnit.supportSKOverlay = v }
    }
}
