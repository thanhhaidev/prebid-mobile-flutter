import 'package:flutter/foundation.dart';

import 'generated/prebid_api.g.dart';

/// Manages targeting information and privacy settings for Prebid Mobile.
///
/// Provides access to GDPR, CCPA/COPPA consent settings, user keywords,
/// app data, and OpenRTB configuration.
class PrebidTargeting {
  @visibleForTesting
  static TargetingHostApi api = TargetingHostApi();

  // ---------------------------------------------------------------------------
  // COPPA
  // ---------------------------------------------------------------------------

  /// Set whether the request is subject to COPPA regulations.
  static Future<void> setSubjectToCOPPA(bool? subject) async {
    api.setSubjectToCOPPA(subject);
  }

  /// Get COPPA subject status.
  static Future<bool?> getSubjectToCOPPA() async {
    return api.getSubjectToCOPPA();
  }

  // ---------------------------------------------------------------------------
  // GDPR
  // ---------------------------------------------------------------------------

  /// Set whether the request is subject to GDPR.
  static Future<void> setSubjectToGDPR(bool? subject) async {
    api.setSubjectToGDPR(subject);
  }

  /// Get GDPR subject status.
  static Future<bool?> getSubjectToGDPR() async {
    return api.getSubjectToGDPR();
  }

  /// Set the GDPR consent string (TCF consent string).
  static Future<void> setGDPRConsentString(String? consent) async {
    api.setGDPRConsentString(consent);
  }

  /// Get the GDPR consent string.
  static Future<String?> getGDPRConsentString() async {
    return api.getGDPRConsentString();
  }

  // ---------------------------------------------------------------------------
  // TCFv2 Purpose Consents
  // ---------------------------------------------------------------------------

  /// Set the TCFv2 purpose consents string.
  static Future<void> setPurposeConsents(String? consents) async {
    api.setPurposeConsents(consents);
  }

  /// Get the TCFv2 purpose consents string.
  static Future<String?> getPurposeConsents() async {
    return api.getPurposeConsents();
  }

  /// Get device access consent (Purpose 1).
  static Future<bool?> getDeviceAccessConsent() async {
    return api.getDeviceAccessConsent();
  }

  // ---------------------------------------------------------------------------
  // User Keywords (user.keywords)
  // ---------------------------------------------------------------------------

  /// Add a user keyword for targeting.
  static Future<void> addUserKeyword(String keyword) async {
    api.addUserKeyword(keyword);
  }

  /// Add multiple user keywords for targeting.
  static Future<void> addUserKeywords(Set<String> keywords) async {
    api.addUserKeywords(keywords.toList());
  }

  /// Remove a user keyword.
  static Future<void> removeUserKeyword(String keyword) async {
    api.removeUserKeyword(keyword);
  }

  /// Clear all user keywords.
  static Future<void> clearUserKeywords() async {
    api.clearUserKeywords();
  }

  /// Get all user keywords.
  static Future<List<String>> getUserKeywords() async {
    return api.getUserKeywords();
  }

  // ---------------------------------------------------------------------------
  // App Keywords (app.keywords)
  // ---------------------------------------------------------------------------

  /// Add an app keyword for targeting.
  static Future<void> addAppKeyword(String keyword) async {
    api.addAppKeyword(keyword);
  }

  /// Add multiple app keywords for targeting.
  static Future<void> addAppKeywords(Set<String> keywords) async {
    api.addAppKeywords(keywords.toList());
  }

  /// Remove an app keyword.
  static Future<void> removeAppKeyword(String keyword) async {
    api.removeAppKeyword(keyword);
  }

  /// Clear all app keywords.
  static Future<void> clearAppKeywords() async {
    api.clearAppKeywords();
  }

  // ---------------------------------------------------------------------------
  // App Ext Data (app.ext.data)
  // ---------------------------------------------------------------------------

  /// Add app-level ext data for a given key.
  static Future<void> addAppExtData({
    required String key,
    required String value,
  }) async {
    api.addAppExtData(key, value);
  }

  /// Update app-level ext data for a given key with a new set of values.
  static Future<void> updateAppExtData({
    required String key,
    required Set<String> value,
  }) async {
    api.updateAppExtData(key, value.toList());
  }

  /// Remove app-level ext data for a given key.
  static Future<void> removeAppExtData(String key) async {
    api.removeAppExtData(key);
  }

  /// Clear all app-level ext data.
  static Future<void> clearAppExtData() async {
    api.clearAppExtData();
  }

  // ---------------------------------------------------------------------------
  // Access Control List (ext.prebid.data)
  // ---------------------------------------------------------------------------

  /// Add a bidder to the access control list.
  static Future<void> addBidderToAccessControlList(String bidderName) async {
    api.addBidderToAccessControlList(bidderName);
  }

  /// Remove a bidder from the access control list.
  static Future<void> removeBidderFromAccessControlList(
    String bidderName,
  ) async {
    api.removeBidderFromAccessControlList(bidderName);
  }

  /// Clear the access control list.
  static Future<void> clearAccessControlList() async {
    api.clearAccessControlList();
  }

  // ---------------------------------------------------------------------------
  // OpenRTB / Global ORTB Config
  // ---------------------------------------------------------------------------

  /// Set the global OpenRTB configuration JSON string.
  static Future<void> setGlobalOrtbConfig(String? ortbConfig) async {
    api.setGlobalOrtbConfig(ortbConfig);
  }

  /// Get the global OpenRTB configuration JSON string.
  static Future<String?> getGlobalOrtbConfig() async {
    return api.getGlobalOrtbConfig();
  }

  // ---------------------------------------------------------------------------
  // App Information
  // ---------------------------------------------------------------------------

  /// Set the content URL for targeting.
  static Future<void> setContentUrl(String? url) async {
    api.setContentUrl(url);
  }

  /// Set the publisher name.
  static Future<void> setPublisherName(String? name) async {
    api.setPublisherName(name);
  }

  /// Set the app store URL.
  static Future<void> setStoreUrl(String? url) async {
    api.setStoreUrl(url);
  }

  /// Set the app domain.
  static Future<void> setDomain(String? domain) async {
    api.setDomain(domain);
  }
}
