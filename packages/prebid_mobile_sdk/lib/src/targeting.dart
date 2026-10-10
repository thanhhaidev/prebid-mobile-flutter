import 'package:flutter/foundation.dart';

import 'generated/prebid_api.g.dart';

/// Manages targeting information and privacy settings for Prebid Mobile.
///
/// This static class provides access to:
/// - **Privacy & Consent** — GDPR, COPPA, TCFv2 purpose consents.
/// - **User Keywords** — Keywords for user-level targeting (`user.keywords`).
/// - **App Keywords** — Keywords for app-level targeting (`app.keywords`).
/// - **First-Party Data** — App ext data (`app.ext.data`) for enriched bid requests.
/// - **Access Control** — Control which bidders can access first-party data.
/// - **OpenRTB Configuration** — Global OpenRTB JSON config merged into every bid request.
/// - **App Information** — Publisher name, store URL, domain, content URL.
///
/// ## Example
///
/// ```dart
/// // Privacy
/// await PrebidTargeting.setSubjectToGDPR(true);
/// await PrebidTargeting.setGDPRConsentString('BOEFEAyOEFEAyAHABDENAI4AAAB9...');
///
/// // First-Party Data
/// await PrebidTargeting.addUserKeyword('sports');
/// await PrebidTargeting.addAppExtData(key: 'segment', value: 'premium');
///
/// // OpenRTB Config
/// await PrebidTargeting.setGlobalOrtbConfig('{"bcat": ["IAB25"]}');
/// ```
class PrebidTargeting {
  // Static members only.
  PrebidTargeting._();

  /// The platform channel to the native SDK; tests replace it with a mock.
  @visibleForTesting
  static TargetingHostApi api = TargetingHostApi();

  // ---------------------------------------------------------------------------
  // COPPA
  // ---------------------------------------------------------------------------

  /// Set whether the request is subject to COPPA regulations.
  ///
  /// Pass `true` to indicate the user is a child under 13, `false` otherwise,
  /// or `null` to clear the flag (let the SDK/server decide).
  static Future<void> setSubjectToCOPPA(bool? subject) async {
    await api.setSubjectToCOPPA(subject);
  }

  /// Get the current COPPA subject status.
  ///
  /// Returns `true`, `false`, or `null` if not set.
  static Future<bool?> getSubjectToCOPPA() async {
    return api.getSubjectToCOPPA();
  }

  // ---------------------------------------------------------------------------
  // GDPR
  // ---------------------------------------------------------------------------

  /// Set whether the request is subject to GDPR.
  ///
  /// Pass `true` for users in the EU/EEA, `false` for users outside,
  /// or `null` to clear the flag.
  static Future<void> setSubjectToGDPR(bool? subject) async {
    await api.setSubjectToGDPR(subject);
  }

  /// Get the current GDPR subject status.
  static Future<bool?> getSubjectToGDPR() async {
    return api.getSubjectToGDPR();
  }

  /// Set the IAB Transparency & Consent Framework (TCF) consent string.
  ///
  /// This is the Base64-encoded consent string obtained from a CMP
  /// (Consent Management Platform).
  static Future<void> setGDPRConsentString(String? consent) async {
    await api.setGDPRConsentString(consent);
  }

  /// Get the current GDPR consent string.
  static Future<String?> getGDPRConsentString() async {
    return api.getGDPRConsentString();
  }

  // ---------------------------------------------------------------------------
  // TCFv2 Purpose Consents
  // ---------------------------------------------------------------------------

  /// Set the TCFv2 purpose consents string.
  ///
  /// This is a binary string where each character represents consent
  /// for a specific TCFv2 purpose (e.g., `"1"` = consented, `"0"` = not).
  static Future<void> setPurposeConsents(String? consents) async {
    await api.setPurposeConsents(consents);
  }

  /// Get the current TCFv2 purpose consents string.
  static Future<String?> getPurposeConsents() async {
    return api.getPurposeConsents();
  }

  /// Consent for one TCF purpose, from the CMP's purpose consents. [index] is
  /// 0-based (purpose 1 is index 0). `null` when unknown.
  static Future<bool?> getPurposeConsent(int index) async {
    return api.getPurposeConsent(index);
  }

  /// Get the device access consent status (TCFv2 Purpose 1).
  ///
  /// Purpose 1 covers "Store and/or access information on a device."
  /// Returns `true` if consented, `false` if not, or `null` if unknown.
  static Future<bool?> getDeviceAccessConsent() async {
    return api.getDeviceAccessConsent();
  }

  /// Whether the consent signals let Prebid read device data (IDFA / AAID):
  /// true when TCF purpose 1 is consented, or unanswered while GDPR doesn't
  /// apply.
  static Future<bool> isAllowedAccessDeviceData() =>
      api.isAllowedAccessDeviceData();

  // ---------------------------------------------------------------------------
  // User Keywords (user.keywords)
  // ---------------------------------------------------------------------------

  /// Add a single user keyword for targeting.
  ///
  /// Keywords are included in the `user.keywords` field of the OpenRTB request.
  static Future<void> addUserKeyword(String keyword) async {
    await api.addUserKeyword(keyword);
  }

  /// Add multiple user keywords for targeting.
  static Future<void> addUserKeywords(Set<String> keywords) async {
    await api.addUserKeywords(keywords.toList());
  }

  /// Remove a single user keyword.
  static Future<void> removeUserKeyword(String keyword) async {
    await api.removeUserKeyword(keyword);
  }

  /// Clear all user keywords.
  static Future<void> clearUserKeywords() async {
    await api.clearUserKeywords();
  }

  /// Retrieve all currently set user keywords.
  static Future<List<String>> getUserKeywords() async {
    return api.getUserKeywords();
  }

  // ---------------------------------------------------------------------------
  // App Keywords (app.keywords)
  // ---------------------------------------------------------------------------

  /// Add a single app keyword for targeting.
  ///
  /// Keywords are included in the `app.keywords` field of the OpenRTB request.
  ///
  /// **iOS only.** Prebid Android has no app-keyword API, so the app-keyword
  /// methods are no-ops there (a warning is logged). For both platforms, set
  /// `app.keywords` via [setGlobalOrtbConfig] instead.
  static Future<void> addAppKeyword(String keyword) async {
    await api.addAppKeyword(keyword);
  }

  /// Add multiple app keywords for targeting.
  static Future<void> addAppKeywords(Set<String> keywords) async {
    await api.addAppKeywords(keywords.toList());
  }

  /// Remove a single app keyword.
  static Future<void> removeAppKeyword(String keyword) async {
    await api.removeAppKeyword(keyword);
  }

  /// Clear all app keywords.
  static Future<void> clearAppKeywords() async {
    await api.clearAppKeywords();
  }

  /// The app keywords. iOS only: always empty on Android, which has no app
  /// keywords.
  static Future<List<String>> getAppKeywords() => api.getAppKeywords();

  // ---------------------------------------------------------------------------
  // App Ext Data (app.ext.data) — First-Party Data
  // ---------------------------------------------------------------------------

  /// Append a value to the app ext data for a given key.
  ///
  /// This adds first-party data to the `app.ext.data` section of the
  /// OpenRTB request. Multiple values can be added for the same key.
  ///
  /// ```dart
  /// await PrebidTargeting.addAppExtData(key: 'segment', value: 'premium');
  /// await PrebidTargeting.addAppExtData(key: 'segment', value: 'sports');
  /// ```
  static Future<void> addAppExtData({
    required String key,
    required String value,
  }) async {
    await api.addAppExtData(key, value);
  }

  /// Replace all ext data values for a given key.
  ///
  /// Unlike [addAppExtData], this overwrites any existing values for [key].
  static Future<void> updateAppExtData({
    required String key,
    required Set<String> value,
  }) async {
    await api.updateAppExtData(key, value.toList());
  }

  /// Remove all app ext data for a given key.
  static Future<void> removeAppExtData(String key) async {
    await api.removeAppExtData(key);
  }

  /// Clear all app ext data entries.
  static Future<void> clearAppExtData() async {
    await api.clearAppExtData();
  }

  // ---------------------------------------------------------------------------
  // Access Control List (ext.prebid.data)
  // ---------------------------------------------------------------------------

  /// Grant a specific bidder access to first-party data.
  ///
  /// Only bidders in the access control list will receive the data
  /// from [addAppExtData] in their bid requests.
  static Future<void> addBidderToAccessControlList(String bidderName) async {
    await api.addBidderToAccessControlList(bidderName);
  }

  /// Revoke a bidder's access to first-party data.
  static Future<void> removeBidderFromAccessControlList(
    String bidderName,
  ) async {
    await api.removeBidderFromAccessControlList(bidderName);
  }

  /// Clear the entire access control list.
  ///
  /// After calling this, no bidders will have explicit access to first-party data.
  static Future<void> clearAccessControlList() async {
    await api.clearAccessControlList();
  }

  // ---------------------------------------------------------------------------
  // OpenRTB / Global ORTB Config
  // ---------------------------------------------------------------------------

  /// Set a global OpenRTB configuration JSON string.
  ///
  /// This JSON is merged into every outgoing bid request, allowing you to
  /// set fields like `bcat` (blocked categories), `badv` (blocked advertisers),
  /// and other OpenRTB 2.x fields.
  ///
  /// ```dart
  /// await PrebidTargeting.setGlobalOrtbConfig('{"bcat": ["IAB25"], "badv": ["example.com"]}');
  /// ```
  ///
  /// Pass `null` to clear the configuration.
  static Future<void> setGlobalOrtbConfig(String? ortbConfig) async {
    await api.setGlobalOrtbConfig(ortbConfig);
  }

  /// Get the current global OpenRTB configuration JSON string.
  static Future<String?> getGlobalOrtbConfig() async {
    return api.getGlobalOrtbConfig();
  }

  // ---------------------------------------------------------------------------
  // App Information
  // ---------------------------------------------------------------------------

  /// Set the publisher name.
  ///
  /// Maps to `app.publisher.name` in the OpenRTB request.
  static Future<void> setPublisherName(String? name) async {
    await api.setPublisherName(name);
  }

  /// Set the app store URL.
  ///
  /// Maps to `app.storeurl` in the OpenRTB request.
  static Future<void> setStoreUrl(String? url) async {
    await api.setStoreUrl(url);
  }

  /// Set the app domain.
  ///
  /// Maps to `app.domain` in the OpenRTB request.
  static Future<void> setDomain(String? domain) async {
    await api.setDomain(domain);
  }

  /// Overrides the app name sent in `app.name` (by default the app's label
  /// on Android and its bundle display name on iOS). Pass `null` to restore
  /// the default.
  ///
  /// An `app.name` in [setGlobalOrtbConfig] takes precedence on both
  /// platforms. iOS: Prebid iOS has no app-name setter, so the plugin merges
  /// `{"app":{"name": name}}` into the global ORTB config it hands the SDK;
  /// [getGlobalOrtbConfig] still returns your own JSON.
  static Future<void> setAppName(String? name) async {
    await api.setAppName(name);
  }

  // ---------------------------------------------------------------------------
  // US Privacy / CCPA
  // ---------------------------------------------------------------------------

  /// Set the IAB US Privacy String for CCPA compliance.
  ///
  /// The string follows the IAB US Privacy String format (e.g., `"1YNN"`).
  /// Pass `null` to clear.
  static Future<void> setUSPrivacyString(String? usPrivacy) async {
    await api.setUSPrivacyString(usPrivacy);
  }

  /// Get the current US Privacy String.
  static Future<String?> getUSPrivacyString() async {
    return api.getUSPrivacyString();
  }

  // ---------------------------------------------------------------------------
  // User Ext Data — First-Party Data (user.ext.data)
  // ---------------------------------------------------------------------------

  /// Append a value to the user ext data for a given key.
  ///
  /// This adds first-party data to the `user.ext.data` section of the
  /// OpenRTB request.
  static Future<void> addUserExtData({
    required String key,
    required String value,
  }) async {
    await api.addUserExtData(key, value);
  }

  /// Replace all user ext data values for a given key.
  static Future<void> updateUserExtData({
    required String key,
    required Set<String> value,
  }) async {
    await api.updateUserExtData(key, value.toList());
  }

  /// Remove all user ext data for a given key.
  static Future<void> removeUserExtData(String key) async {
    await api.removeUserExtData(key);
  }

  /// Clear all user ext data entries.
  static Future<void> clearUserExtData() async {
    await api.clearUserExtData();
  }

  // ---------------------------------------------------------------------------
  // OM SDK partner
  // ---------------------------------------------------------------------------

  /// iOS only: the SKAdNetwork `sourceapp` (your app's iTunes ID), required
  /// for SKAdNetwork bids when your Info.plist lists `SKAdNetworkItems`.
  static Future<void> setSourceApp(String? sourceApp) async {
    await api.setSourceApp(sourceApp);
  }

  /// iOS only: your app's iTunes ID, sent as the App Store URL.
  static Future<void> setItunesId(String? itunesId) async {
    await api.setItunesId(itunesId);
  }

  /// The SKAdNetwork `sourceapp` ([setSourceApp]); null on Android.
  static Future<String?> getSourceApp() => api.getSourceApp();

  /// The iTunes ID ([setItunesId]); null on Android.
  static Future<String?> getItunesId() => api.getItunesId();

  /// Android only: overrides `app.bundle` (e.g. to test against a Prebid
  /// Server account set up for your production bundle); null restores the
  /// package name. iOS sends the bundle ID, or [setItunesId] when set.
  static Future<void> setBundleName(String? bundleName) async {
    await api.setBundleName(bundleName);
  }

  /// The `app.bundle` override ([setBundleName]); null on iOS.
  static Future<String?> getBundleName() => api.getBundleName();

  /// OM SDK partner name sent in `source.ext.omidpn`.
  static Future<void> setOmidPartnerName(String? name) async {
    await api.setOmidPartnerName(name);
  }

  /// OM SDK partner version sent in `source.ext.omidpv`.
  static Future<void> setOmidPartnerVersion(String? version) async {
    await api.setOmidPartnerVersion(version);
  }

  // ---------------------------------------------------------------------------
  // Location
  // ---------------------------------------------------------------------------

  /// Sets the user's location (`user.geo`).
  static Future<void> setUserLatLng(double latitude, double longitude) async {
    await api.setUserLatLng(latitude, longitude);
  }

  /// Removes the location set with [setUserLatLng].
  static Future<void> clearUserLatLng() async {
    await api.clearUserLatLng();
  }

  /// Number of decimal places kept when rounding device / user coordinates.
  /// `null` sends full precision.
  static Future<void> setLocationPrecision(int? precision) async {
    await api.setLocationPrecision(precision);
  }

  /// The app ext data, key → values ([addAppExtData]).
  static Future<Map<String, List<String>>> getAppExtData() async {
    final data = await api.getAppExtData();
    return {
      for (final MapEntry(:key, :value) in data.entries) key: [...value],
    };
  }

  /// The bidders allowed to read first-party data
  /// ([addBidderToAccessControlList]).
  static Future<List<String>> getAccessControlList() =>
      api.getAccessControlList();

  /// The publisher name, or null ([setPublisherName]).
  static Future<String?> getPublisherName() => api.getPublisherName();

  /// The app store URL, or null ([setStoreUrl]).
  static Future<String?> getStoreUrl() => api.getStoreUrl();

  /// The app domain, or null ([setDomain]).
  static Future<String?> getDomain() => api.getDomain();

  /// The OMID partner name, or null ([setOmidPartnerName]).
  static Future<String?> getOmidPartnerName() => api.getOmidPartnerName();

  /// The OMID partner version, or null ([setOmidPartnerVersion]).
  static Future<String?> getOmidPartnerVersion() => api.getOmidPartnerVersion();

  /// Whether the SharedID is sent ([PrebidMobile.setSendSharedId]).
  static Future<bool> getSendSharedId() => api.getSendSharedId();

  /// The user location as (latitude, longitude), or null
  /// ([setUserLatLng]).
  static Future<(double, double)?> getUserLatLng() async {
    final location = await api.getUserLatLng();
    if (location == null || location.length != 2) return null;
    return (location[0], location[1]);
  }

  /// The location precision in decimal places, or null (full precision;
  /// [setLocationPrecision]).
  static Future<int?> getLocationPrecision() => api.getLocationPrecision();
}
