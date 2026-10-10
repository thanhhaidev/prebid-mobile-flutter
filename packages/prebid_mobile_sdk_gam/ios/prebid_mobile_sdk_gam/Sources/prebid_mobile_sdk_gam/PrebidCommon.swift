import Foundation
import UIKit
import PrebidMobile

// Shared by the core package and the GAM package; tool/check_copies.sh
// keeps the copies identical.

/// The result-code names the Dart API uses (matching the Android mapping),
/// so both platforms report the same strings.
extension ResultCode {
    var dartCode: String {
        switch self {
        case .prebidDemandFetchSuccess: return "prebidDemandFetchSuccess"
        case .prebidServerNotSpecified: return "prebidServerNotSpecified"
        case .prebidInvalidAccountId: return "prebidInvalidAccountId"
        case .prebidInvalidConfigId: return "prebidInvalidConfigId"
        case .prebidInvalidSize: return "prebidInvalidSize"
        case .prebidNetworkError: return "prebidNetworkError"
        case .prebidServerError: return "prebidServerError"
        case .prebidDemandNoBids: return "prebidDemandNoBids"
        case .prebidDemandTimedOut: return "prebidDemandTimedOut"
        case .prebidServerURLInvalid: return "prebidServerURLInvalid"
        case .prebidDemandNoCachedBids: return "prebidDemandNoCachedBids"
        case .prebidUnknownError: return "prebidUnknownError"
        case .prebidInvalidResponseStructure: return "prebidInvalidResponseStructure"
        case .prebidInternalSDKError: return "prebidInternalSDKError"
        case .prebidWrongArguments: return "prebidWrongArguments"
        case .prebidNoVastTagInMediaData: return "prebidNoVastTagInMediaData"
        case .prebidSDKMisuse, .prebidSDKMisusePreviousFetchNotCompletedYet: return "prebidSDKMisuse"
        default: return "prebidInvalidRequest"
        }
    }
}

/// Downloads the image at `urlString` and shows it in `imageView`; nothing
/// on failure.
func downloadNativeImage(_ urlString: String?, into imageView: UIImageView) {
    guard let urlString = urlString, let url = URL(string: urlString) else { return }
    URLSession.shared.dataTask(with: url) { data, _, _ in
        guard let data = data, let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { imageView.image = image }
    }.resume()
}
