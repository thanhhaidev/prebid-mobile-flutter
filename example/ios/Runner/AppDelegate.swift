import Flutter
import PrebidMobile
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        registerIabConsentStore(messenger: engineBridge.applicationRegistrar.messenger())
        registerCustomRenderer(messenger: engineBridge.applicationRegistrar.messenger())
    }

    /// The original's plugin renderer, registered while a "[Custom Renderer]"
    /// screen is open (lib/services/custom_renderer.dart).
    private let customRenderer = SampleRenderer()

    private func registerCustomRenderer(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "prebid_example/custom_renderer", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let renderer = self?.customRenderer else {
                result(nil)
                return
            }
            switch call.method {
            case "register":
                Prebid.registerPluginRenderer(renderer)
                result(nil)
            case "unregister":
                Prebid.unregisterPluginRenderer(renderer)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    /// Example-only channel: raw IAB consent keys in `UserDefaults.standard`, where
    /// the Prebid SDK reads them (see lib/services/iab_consent_store.dart).
    private func registerIabConsentStore(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: "prebid_example/iab_consent_store", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            let defaults = UserDefaults.standard
            guard let args = call.arguments as? [String: Any],
                let key = args["key"] as? String
            else {
                result(FlutterError(code: "bad_args", message: "missing key", details: nil))
                return
            }
            let value = args["value"]
            switch call.method {
            case "get":
                result(defaults.object(forKey: key))
            case "setInt":
                if let number = value as? NSNumber {
                    defaults.set(number.intValue, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
                result(nil)
            case "setString":
                if let string = value as? String {
                    defaults.set(string, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
                result(nil)
            case "setBool":
                if let flag = value as? Bool {
                    defaults.set(flag, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
                result(nil)
            case "remove":
                defaults.removeObject(forKey: key)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
