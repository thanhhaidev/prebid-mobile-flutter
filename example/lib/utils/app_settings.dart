import 'package:shared_preferences/shared_preferences.dart';

/// Settings persistence using SharedPreferences.
///
/// Saves and loads user settings across app restarts.
class AppSettings {
  static const _keyServerUrl = 'pbs_server_url';
  static const _keyAccountId = 'pbs_account_id';
  static const _keyPbsDebug = 'pbs_debug';
  static const _keyShareGeo = 'share_geo';
  static const _keyCoppa = 'coppa';
  static const _keyGdpr = 'gdpr';
  static const _keyGdprConsent = 'gdpr_consent';
  static const _keyLogLevel = 'log_level';
  static const _keyDarkMode = 'dark_mode';

  static const defaultServerUrl =
      'https://prebid-server-test-j.prebid.org/openrtb2/auction';
  static const defaultAccountId = '0689a263-318d-448b-a3d4-b02e8a709d9d';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Getters ---

  static String get serverUrl =>
      _prefs?.getString(_keyServerUrl) ?? defaultServerUrl;

  static String get accountId =>
      _prefs?.getString(_keyAccountId) ?? defaultAccountId;

  static bool get pbsDebug => _prefs?.getBool(_keyPbsDebug) ?? true;
  static bool get shareGeo => _prefs?.getBool(_keyShareGeo) ?? false;
  static bool get coppa => _prefs?.getBool(_keyCoppa) ?? false;
  static bool get gdpr => _prefs?.getBool(_keyGdpr) ?? false;
  static String get gdprConsent => _prefs?.getString(_keyGdprConsent) ?? '';
  static int get logLevelIndex => _prefs?.getInt(_keyLogLevel) ?? 3; // debug
  static bool get darkMode => _prefs?.getBool(_keyDarkMode) ?? false;

  // --- Setters ---

  static Future<void> setServerUrl(String v) async =>
      _prefs?.setString(_keyServerUrl, v);

  static Future<void> setAccountId(String v) async =>
      _prefs?.setString(_keyAccountId, v);

  static Future<void> setPbsDebug(bool v) async =>
      _prefs?.setBool(_keyPbsDebug, v);

  static Future<void> setShareGeo(bool v) async =>
      _prefs?.setBool(_keyShareGeo, v);

  static Future<void> setCoppa(bool v) async => _prefs?.setBool(_keyCoppa, v);

  static Future<void> setGdpr(bool v) async => _prefs?.setBool(_keyGdpr, v);

  static Future<void> setGdprConsent(String v) async =>
      _prefs?.setString(_keyGdprConsent, v);

  static Future<void> setLogLevel(int v) async =>
      _prefs?.setInt(_keyLogLevel, v);

  static Future<void> setDarkMode(bool v) async =>
      _prefs?.setBool(_keyDarkMode, v);

  // --- Reset ---

  static Future<void> resetDefaults() async {
    await _prefs?.remove(_keyServerUrl);
    await _prefs?.remove(_keyAccountId);
    await _prefs?.remove(_keyPbsDebug);
    await _prefs?.remove(_keyShareGeo);
    await _prefs?.remove(_keyCoppa);
    await _prefs?.remove(_keyGdpr);
    await _prefs?.remove(_keyGdprConsent);
    await _prefs?.remove(_keyLogLevel);
    // Note: dark mode is NOT reset
  }
}
