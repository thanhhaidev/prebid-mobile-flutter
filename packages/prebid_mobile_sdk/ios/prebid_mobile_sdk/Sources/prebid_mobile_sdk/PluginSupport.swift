import Flutter
import UIKit

/// Formats Prebid errors, appending `localizedFailureReason` (the real server
/// response) which the SDK hides behind a generic `localizedDescription`.
enum PrebidErrorFormatter {
    static func describe(_ error: Error?) -> String {
        guard let error = error else { return "Unknown error" }
        let nsError = error as NSError
        let description = nsError.localizedDescription
        if let reason = nsError.localizedFailureReason,
            !reason.isEmpty,
            reason != description
        {
            return "\(description): \(reason)"
        }
        return description
    }
}

/// Finds the view controller to present fullscreen ads from: the top-most
/// presented controller of the foreground key window (scene-aware;
/// `UIApplication.keyWindow` is deprecated and nil in multi-scene apps).
enum PrebidPresenter {
    static func topViewController() -> UIViewController? {
        // Prefer the active scene, but fall back to an inactive one: the
        // scene is inactive while a system alert (e.g. ATT) or Notification
        // Center is over the app, and when returning from the background.
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows =
            (scenes.filter { $0.activationState == .foregroundActive }
            + scenes.filter { $0.activationState == .foregroundInactive })
            .flatMap { $0.windows }
        let window = windows.first { $0.isKeyWindow } ?? windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    /// Calls `present` with a controller that can present now, or `fail`
    /// with the reason. A controller still presenting or dismissing another
    /// makes UIKit drop the presentation with only a console warning, after
    /// Prebid has already reported the ad as displayed; so that case waits
    /// once for the running transition (or the next run loop), then fails.
    static func whenReady(
        retry: Bool = true,
        fail: @escaping (String) -> Void,
        present: @escaping (UIViewController) -> Void
    ) {
        guard let top = topViewController() else { return fail(noViewController) }
        guard isBusy(top) else { return present(top) }
        guard retry else { return fail(busy) }
        let again = {
            DispatchQueue.main.async {
                PrebidPresenter.whenReady(retry: false, fail: fail, present: present)
            }
        }
        if let coordinator = (top.presentedViewController ?? top).transitionCoordinator {
            _ = coordinator.animate(alongsideTransition: nil) { _ in again() }
        } else {
            again()
        }
    }

    private static func isBusy(_ controller: UIViewController) -> Bool {
        controller.presentedViewController != nil
            || controller.isBeingPresented
            || controller.isBeingDismissed
    }

    static let noViewController = "No view controller to present the ad from"
    static let notReady = "The ad is not loaded"
    static let busy = "Another view controller is being presented; try again after it is dismissed"
}

/// Keeps ad units alive while `fetchDemand` runs. Prebid guards its response
/// and timeout handlers with `[weak self]`, so releasing the unit mid-request
/// (destroy, or a new fetch for the same ad) drops the completion and leaves
/// the Dart Future pending. Not captured in the completion itself: the unit
/// stores it (`lastFetchDemandCompletion`), which would be a retain cycle.
enum InFlightAdUnits {
    private static var units: [ObjectIdentifier: AnyObject] = [:]

    static func retain(_ unit: AnyObject) {
        units[ObjectIdentifier(unit)] = unit
    }

    static func release(_ id: ObjectIdentifier) {
        units.removeValue(forKey: id)
    }
}

extension AdFlutterApi {
    /// Reports `onAdFailed` with [error] for [adId].
    func sendAdFailed(_ adId: Int64, _ error: String) {
        onAdEvent(event: AdEvent(adId: adId, eventName: "onAdFailed", error: error)) { _ in }
    }
}
