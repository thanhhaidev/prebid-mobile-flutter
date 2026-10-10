import Flutter
import UIKit

/// Entry point of the core plugin: registers the Pigeon host APIs and the
/// banner / native platform views.
public final class PrebidMobileSdkPlugin: NSObject, FlutterPlugin {
    static let bannerViewType = "prebid_mobile_sdk/banner_ad"
    static let nativeViewType = "prebid_mobile_sdk/native_ad"

    private let nativeAdStore = NativeAdStore()
    private var prebidMobileApi: PrebidMobileHostApiImpl?
    private var interstitialApi: InterstitialAdHostApiImpl?
    private var rewardedApi: RewardedAdHostApiImpl?
    private var nativeApi: NativeAdHostApiImpl?
    private var multiformatApi: MultiformatAdHostApiImpl?
    private var instreamApi: InstreamVideoAdHostApiImpl?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let flutterApi = AdFlutterApi(binaryMessenger: messenger)
        let instance = PrebidMobileSdkPlugin()

        let prebidMobileApi = PrebidMobileHostApiImpl(
            eventFlutterApi: PrebidEventFlutterApi(binaryMessenger: messenger),
            releaseAds: { [weak instance] in instance?.releaseAllAds() }
        )
        let interstitialApi = InterstitialAdHostApiImpl(flutterApi: flutterApi)
        let rewardedApi = RewardedAdHostApiImpl(flutterApi: flutterApi)
        let nativeApi = NativeAdHostApiImpl(flutterApi: flutterApi, store: instance.nativeAdStore)
        let multiformatApi = MultiformatAdHostApiImpl(flutterApi: MultiformatFlutterApi(binaryMessenger: messenger))
        let instreamApi = InstreamVideoAdHostApiImpl()
        instance.prebidMobileApi = prebidMobileApi
        instance.interstitialApi = interstitialApi
        instance.rewardedApi = rewardedApi
        instance.nativeApi = nativeApi
        instance.multiformatApi = multiformatApi
        instance.instreamApi = instreamApi

        PrebidMobileHostApiSetup.setUp(binaryMessenger: messenger, api: prebidMobileApi)
        TargetingHostApiSetup.setUp(binaryMessenger: messenger, api: TargetingHostApiImpl())
        InterstitialAdHostApiSetup.setUp(binaryMessenger: messenger, api: interstitialApi)
        RewardedAdHostApiSetup.setUp(binaryMessenger: messenger, api: rewardedApi)
        NativeAdHostApiSetup.setUp(binaryMessenger: messenger, api: nativeApi)
        MultiformatAdHostApiSetup.setUp(binaryMessenger: messenger, api: multiformatApi)
        InstreamVideoAdHostApiSetup.setUp(binaryMessenger: messenger, api: instreamApi)

        registrar.register(BannerAdViewFactory(messenger: messenger), withId: bannerViewType)
        registrar.register(
            NativeAdViewFactory(messenger: messenger, store: instance.nativeAdStore),
            withId: nativeViewType
        )

        // Published so the engine calls detachFromEngine(for:) on teardown.
        registrar.publish(instance)
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        // Stop auto-refresh and viewability timers, which would otherwise
        // keep running for the rest of the process.
        releaseAllAds()
        prebidMobileApi?.clearEventDelegate()
        prebidMobileApi?.clearLogger()
    }

    private func releaseAllAds() {
        _ = interstitialApi?.destroyAll()
        _ = rewardedApi?.destroyAll()
        nativeApi?.destroyAll()
        multiformatApi?.destroyAll()
        instreamApi?.destroyAll()
    }
}
