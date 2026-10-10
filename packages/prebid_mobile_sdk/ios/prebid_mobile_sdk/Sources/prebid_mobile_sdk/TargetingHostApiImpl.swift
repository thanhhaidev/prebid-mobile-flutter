import Flutter
import MapKit
import PrebidMobile

/// TargetingHostApi: privacy signals, keywords, ext data and app info.
final class TargetingHostApiImpl: TargetingHostApi {
    func setSubjectToCOPPA(value: Bool?) throws { Targeting.shared.subjectToCOPPA = value }
    func getSubjectToCOPPA() throws -> Bool? { Targeting.shared.subjectToCOPPA }

    func setSubjectToGDPR(value: Bool?) throws { Targeting.shared.subjectToGDPR = value }
    func getSubjectToGDPR() throws -> Bool? { Targeting.shared.subjectToGDPR }

    func setGDPRConsentString(value: String?) throws { Targeting.shared.gdprConsentString = value }
    func getGDPRConsentString() throws -> String? { Targeting.shared.gdprConsentString }

    func setPurposeConsents(value: String?) throws { Targeting.shared.purposeConsents = value }
    func getPurposeConsents() throws -> String? { Targeting.shared.purposeConsents }
    func getPurposeConsent(index: Int64) throws -> Bool? { Targeting.shared.getPurposeConsent(index: Int(index)) }
    func getDeviceAccessConsent() throws -> Bool? { Targeting.shared.getDeviceAccessConsent() }
    func isAllowedAccessDeviceData() throws -> Bool { Targeting.shared.isAllowedAccessDeviceData() }

    // US Privacy / CCPA
    func setUSPrivacyString(value: String?) throws {
        if let val_ = value {
            UserDefaults.standard.set(val_, forKey: "IABUSPrivacy_String")
        } else {
            UserDefaults.standard.removeObject(forKey: "IABUSPrivacy_String")
        }
    }
    func getUSPrivacyString() throws -> String? {
        return UserDefaults.standard.string(forKey: "IABUSPrivacy_String")
    }

    func addUserKeyword(keyword: String) throws { Targeting.shared.addUserKeyword(keyword) }
    func addUserKeywords(keywords: [String]) throws { Targeting.shared.addUserKeywords(Set(keywords)) }
    func removeUserKeyword(keyword: String) throws { Targeting.shared.removeUserKeyword(keyword) }
    func clearUserKeywords() throws { Targeting.shared.clearUserKeywords() }
    func getUserKeywords() throws -> [String] { Targeting.shared.getUserKeywords() }

    func addAppKeyword(keyword: String) throws { Targeting.shared.addAppKeyword(keyword) }
    func addAppKeywords(keywords: [String]) throws { Targeting.shared.addAppKeywords(Set(keywords)) }
    func removeAppKeyword(keyword: String) throws { Targeting.shared.removeAppKeyword(keyword) }
    func clearAppKeywords() throws { Targeting.shared.clearAppKeywords() }
    func getAppKeywords() throws -> [String] { Targeting.shared.getAppKeywords() }

    func addAppExtData(key: String, value: String) throws { Targeting.shared.addAppExtData(key: key, value: value) }
    func updateAppExtData(key: String, value: [String]) throws { Targeting.shared.updateAppExtData(key: key, value: Set(value)) }
    func removeAppExtData(key: String) throws { Targeting.shared.removeAppExtData(for: key) }
    func clearAppExtData() throws { Targeting.shared.clearAppExtData() }

    // User Ext Data (user.ext.data). Tracked locally and written to
    // Targeting.userExt["data"], which Prebid merges into user.ext — leaving
    // the global ORTB config and any other user.ext keys untouched.
    private static var userExtDataMap: [String: Set<String>] = [:]

    func addUserExtData(key: String, value: String) throws {
        Self.userExtDataMap[key, default: []].insert(value)
        syncUserExtData()
    }
    func updateUserExtData(key: String, value: [String]) throws {
        Self.userExtDataMap[key] = Set(value)
        syncUserExtData()
    }
    func removeUserExtData(key: String) throws {
        Self.userExtDataMap.removeValue(forKey: key)
        syncUserExtData()
    }
    func clearUserExtData() throws {
        Self.userExtDataMap.removeAll()
        syncUserExtData()
    }

    // The whole user.ext (setUserExt); its `data` gives way to the user ext
    // data keys when any is set. Until the first setUserExt, the keys already
    // in Targeting.userExt are kept.
    private static var userExtBase: [String: AnyHashable]?

    func setUserExt(json: String?) throws {
        Self.userExtBase = (jsonObject(json) as? [String: AnyHashable]) ?? [:]
        syncUserExtData()
    }

    func getUserExt() throws -> String? {
        guard let ext = Targeting.shared.userExt,
              let data = try? JSONSerialization.data(withJSONObject: ext) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func syncUserExtData() {
        let base = Self.userExtBase
        var ext = base ?? Targeting.shared.userExt ?? [:]
        let map = Self.userExtDataMap
        if map.isEmpty {
            if base == nil { ext.removeValue(forKey: "data") }
        } else {
            ext["data"] = map.mapValues { Array($0).sorted() } as [String: [String]]
        }
        Targeting.shared.userExt = ext.isEmpty ? nil : ext
    }

    func addBidderToAccessControlList(bidderName: String) throws { Targeting.shared.addBidderToAccessControlList(bidderName) }
    func removeBidderFromAccessControlList(bidderName: String) throws { Targeting.shared.removeBidderFromAccessControlList(bidderName) }
    func clearAccessControlList() throws { Targeting.shared.clearAccessControlList() }

    func setGlobalOrtbConfig(ortbConfig: String?) throws {
        Self.globalOrtbConfig = ortbConfig
        applyGlobalOrtbConfig()
    }

    func getGlobalOrtbConfig() throws -> String? {
        // The caller's own JSON, without the app.name merged in below.
        Self.appNameOverride == nil
            ? Targeting.shared.getGlobalORTBConfig()
            : Self.globalOrtbConfig
    }

    // app.name override. Prebid iOS always sends the bundle display name and
    // has no setter (Android: AppInfoManager.setAppName), so the name goes in
    // through the global ORTB config, which Prebid deep-merges over the
    // request. An app.name in the caller's own config wins, as on Android.
    private static var globalOrtbConfig: String?
    private static var appNameOverride: String?

    func setAppName(name: String?) throws {
        Self.appNameOverride = name
        applyGlobalOrtbConfig()
    }

    private func applyGlobalOrtbConfig() {
        let config = Self.globalOrtbConfig
        guard let name = Self.appNameOverride else {
            Targeting.shared.setGlobalORTBConfig(config)
            return
        }
        // Invalid JSON is ignored by Prebid anyway; the name is still sent.
        var root: [String: Any] = [:]
        if let data = config?.data(using: .utf8),
           let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            root = parsed
        }
        var app = root["app"] as? [String: Any] ?? [:]
        if app["name"] == nil { app["name"] = name }
        root["app"] = app
        let merged = (try? JSONSerialization.data(withJSONObject: root))
            .flatMap { String(data: $0, encoding: .utf8) }
        Targeting.shared.setGlobalORTBConfig(merged ?? config)
    }

    func setPublisherName(name: String?) throws { Targeting.shared.publisherName = name }
    func setStoreUrl(url: String?) throws { Targeting.shared.storeURL = url }
    func setDomain(domain: String?) throws { Targeting.shared.domain = domain }

    func setSourceApp(sourceApp: String?) throws { Targeting.shared.sourceapp = sourceApp }
    func setItunesId(itunesId: String?) throws { Targeting.shared.itunesID = itunesId }
    func getSourceApp() throws -> String? { Targeting.shared.sourceapp }
    func getItunesId() throws -> String? { Targeting.shared.itunesID }

    // Android only: Prebid iOS sends the bundle ID (or itunesID) as app.bundle.
    func setBundleName(bundleName: String?) throws {}
    func getBundleName() throws -> String? { nil }

    func setOmidPartnerName(name: String?) throws { Targeting.shared.omidPartnerName = name }
    func setOmidPartnerVersion(version: String?) throws { Targeting.shared.omidPartnerVersion = version }

    func setUserLatLng(latitude: Double, longitude: Double) throws {
        Targeting.shared.setLatitude(latitude, longitude: longitude)
    }
    func clearUserLatLng() throws { Targeting.shared.coordinate = nil }
    func setLocationPrecision(precision: Int64?) throws {
        Targeting.shared.locationPrecision = precision.map { NSNumber(value: $0) }
    }

    func getAppExtData() throws -> [String: [String]] { Targeting.shared.getAppExtData() }
    func getAccessControlList() throws -> [String] { Targeting.shared.getAccessControlList() }
    func getPublisherName() throws -> String? { Targeting.shared.publisherName }
    func getStoreUrl() throws -> String? { Targeting.shared.storeURL }
    func getDomain() throws -> String? { Targeting.shared.domain }
    func getOmidPartnerName() throws -> String? { Targeting.shared.omidPartnerName }
    func getOmidPartnerVersion() throws -> String? { Targeting.shared.omidPartnerVersion }
    func getSendSharedId() throws -> Bool { Targeting.shared.sendSharedId }

    func getUserLatLng() throws -> [Double]? {
        guard let coordinate = Targeting.shared.coordinate?.mkCoordinateValue else { return nil }
        return [coordinate.latitude, coordinate.longitude]
    }

    func getLocationPrecision() throws -> Int64? { Targeting.shared.locationPrecision?.int64Value }
}
