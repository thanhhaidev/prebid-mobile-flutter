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
    api.setSubjectToCOPPA(subject);
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
    api.setSubjectToGDPR(subject);
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
    api.setGDPRConsentString(consent);
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
    api.setPurposeConsents(consents);
  }

  /// Get the current TCFv2 purpose consents string.
  static Future<String?> getPurposeConsents() async {
    return api.getPurposeConsents();
  }

  /// Get the device access consent status (TCFv2 Purpose 1).
  ///
  /// Purpose 1 covers "Store and/or access information on a device."
  /// Returns `true` if consented, `false` if not, or `null` if unknown.
  static Future<bool?> getDeviceAccessConsent() async {
    return api.getDeviceAccessConsent();
  }

  // ---------------------------------------------------------------------------
  // User Keywords (user.keywords)
  // ---------------------------------------------------------------------------

  /// Add a single user keyword for targeting.
  ///
  /// Keywords are included in the `user.keywords` field of the OpenRTB request.
  static Future<void> addUserKeyword(String keyword) async {
    api.addUserKeyword(keyword);
  }

  /// Add multiple user keywords for targeting.
  static Future<void> addUserKeywords(Set<String> keywords) async {
    api.addUserKeywords(keywords.toList());
  }

  /// Remove a single user keyword.
  static Future<void> removeUserKeyword(String keyword) async {
    api.removeUserKeyword(keyword);
  }

  /// Clear all user keywords.
  static Future<void> clearUserKeywords() async {
    api.clearUserKeywords();
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
  static Future<void> addAppKeyword(String keyword) async {
    api.addAppKeyword(keyword);
  }

  /// Add multiple app keywords for targeting.
  static Future<void> addAppKeywords(Set<String> keywords) async {
    api.addAppKeywords(keywords.toList());
  }

  /// Remove a single app keyword.
  static Future<void> removeAppKeyword(String keyword) async {
    api.removeAppKeyword(keyword);
  }

  /// Clear all app keywords.
  static Future<void> clearAppKeywords() async {
    api.clearAppKeywords();
  }

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
    api.addAppExtData(key, value);
  }

  /// Replace all ext data values for a given key.
  ///
  /// Unlike [addAppExtData], this overwrites any existing values for [key].
  static Future<void> updateAppExtData({
    required String key,
    required Set<String> value,
  }) async {
    api.updateAppExtData(key, value.toList());
  }

  /// Remove all app ext data for a given key.
  static Future<void> removeAppExtData(String key) async {
    api.removeAppExtData(key);
  }

  /// Clear all app ext data entries.
  static Future<void> clearAppExtData() async {
    api.clearAppExtData();
  }

  // ---------------------------------------------------------------------------
  // Access Control List (ext.prebid.data)
  // ---------------------------------------------------------------------------

  /// Grant a specific bidder access to first-party data.
  ///
  /// Only bidders in the access control list will receive the data
  /// from [addAppExtData] in their bid requests.
  static Future<void> addBidderToAccessControlList(String bidderName) async {
    api.addBidderToAccessControlList(bidderName);
  }

  /// Revoke a bidder's access to first-party data.
  static Future<void> removeBidderFromAccessControlList(
    String bidderName,
  ) async {
    api.removeBidderFromAccessControlList(bidderName);
  }

  /// Clear the entire access control list.
  ///
  /// After calling this, no bidders will have explicit access to first-party data.
  static Future<void> clearAccessControlList() async {
    api.clearAccessControlList();
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
    api.setGlobalOrtbConfig(ortbConfig);
  }

  /// Get the current global OpenRTB configuration JSON string.
  static Future<String?> getGlobalOrtbConfig() async {
    return api.getGlobalOrtbConfig();
  }

  // ---------------------------------------------------------------------------
  // App Information
  // ---------------------------------------------------------------------------

  /// Set the content URL for contextual targeting.
  ///
  /// Maps to `app.content.url` in the OpenRTB request.
  static Future<void> setContentUrl(String? url) async {
    api.setContentUrl(url);
  }

  /// Set the publisher name.
  ///
  /// Maps to `app.publisher.name` in the OpenRTB request.
  static Future<void> setPublisherName(String? name) async {
    api.setPublisherName(name);
  }

  /// Set the app store URL.
  ///
  /// Maps to `app.storeurl` in the OpenRTB request.
  static Future<void> setStoreUrl(String? url) async {
    api.setStoreUrl(url);
  }

  /// Set the app domain.
  ///
  /// Maps to `app.domain` in the OpenRTB request.
  static Future<void> setDomain(String? domain) async {
    api.setDomain(domain);
  }

  // ---------------------------------------------------------------------------
  // US Privacy / CCPA
  // ---------------------------------------------------------------------------

  /// Set the IAB US Privacy String for CCPA compliance.
  ///
  /// The string follows the IAB US Privacy String format (e.g., `"1YNN"`).
  /// Pass `null` to clear.
  static Future<void> setUSPrivacyString(String? usPrivacy) async {
    api.setUSPrivacyString(usPrivacy);
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
    api.addUserExtData(key, value);
  }

  /// Replace all user ext data values for a given key.
  static Future<void> updateUserExtData({
    required String key,
    required Set<String> value,
  }) async {
    api.updateUserExtData(key, value.toList());
  }

  /// Remove all user ext data for a given key.
  static Future<void> removeUserExtData(String key) async {
    api.removeUserExtData(key);
  }

  /// Clear all user ext data entries.
  static Future<void> clearUserExtData() async {
    api.clearUserExtData();
  }
}
