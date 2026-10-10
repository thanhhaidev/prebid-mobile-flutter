import 'package:flutter/services.dart';

/// Raw IAB consent keys in the platform's default key-value store — the store
/// the Prebid SDKs read consent from:
///
/// - Android: `PreferenceManager.getDefaultSharedPreferences(context)`
///   (`<applicationId>_preferences.xml`),
/// - iOS: `NSUserDefaults.standardUserDefaults`.
///
/// Unlike `shared_preferences`, keys are written verbatim (no `flutter.`
/// prefix) and with their native types (int / String / bool), as the
/// original test app's PreferenceScreen does. Backed by an example-only
/// method channel implemented in `android/.../MainActivity.kt` and
/// `ios/Runner/AppDelegate.swift`.
abstract final class IabConsentStore {
  static const _channel = MethodChannel('prebid_example/iab_consent_store');

  // TCF v1
  static const cmpPresent = 'IABConsent_CMPPresent';
  static const subjectToGdprV1 = 'IABConsent_SubjectToGDPR';
  static const consentStringV1 = 'IABConsent_ConsentString';

  // TCF v2
  static const cmpSdkId = 'IABTCF_CmpSdkID';
  static const gdprApplies = 'IABTCF_gdprApplies';
  static const tcString = 'IABTCF_TCString';

  // CCPA
  static const usPrivacyString = 'IABUSPrivacy_String';

  // Testing
  static const keepSettings = 'IABConsent__KeepSettings';

  /// The stored value of [key] (int, String, bool, ...) or `null`.
  static Future<Object?> get(String key) async {
    try {
      return await _channel.invokeMethod<Object?>('get', {'key': key});
    } on MissingPluginException {
      return null; // widget tests / unsupported platform
    }
  }

  static Future<int?> getInt(String key) async {
    final v = await get(key);
    return v is int ? v : (v is String ? int.tryParse(v) : null);
  }

  static Future<String?> getString(String key) async {
    final v = await get(key);
    return v?.toString();
  }

  static Future<bool> getBool(String key) async => await get(key) == true;

  static Future<bool> contains(String key) async => await get(key) != null;

  static Future<void> setInt(String key, int value) =>
      _invoke('setInt', key, value);

  static Future<void> setString(String key, String value) =>
      _invoke('setString', key, value);

  static Future<void> setBool(String key, bool value) =>
      _invoke('setBool', key, value);

  static Future<void> remove(String key) => _invoke('remove', key, null);

  static Future<void> _invoke(String method, String key, Object? value) async {
    try {
      await _channel.invokeMethod<void>(method, {'key': key, 'value': value});
    } on MissingPluginException {
      // widget tests / unsupported platform
    }
  }

  // -------------------------------------------------------------------------
  // "Enable GDPR" switch of the Examples screen (original GdprHelper.kt)
  // -------------------------------------------------------------------------

  /// ON when `IABTCF_gdprApplies == 1` or `IABTCF_CmpSdkID` is absent — i.e.
  /// ON on a fresh install.
  static Future<bool> isGdprEnabled() async {
    final applies = await getInt(gdprApplies);
    final hasCmp = await contains(cmpSdkId);
    return applies == 1 || !hasCmp;
  }

  /// Checked ⇒ removes `IABTCF_gdprApplies` and `IABTCF_CmpSdkID`;
  /// unchecked ⇒ `IABTCF_gdprApplies = 0` and `IABTCF_CmpSdkID = 123` (ints).
  static Future<void> setGdprEnabled(bool enabled) async {
    if (enabled) {
      await remove(gdprApplies);
      await remove(cmpSdkId);
    } else {
      await setInt(gdprApplies, 0);
      await setInt(cmpSdkId, 123);
    }
  }
}
