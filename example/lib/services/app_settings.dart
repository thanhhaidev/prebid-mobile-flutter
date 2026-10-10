import 'package:flutter/material.dart' show ThemeMode, ValueNotifier;
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted settings (shared_preferences).
///
/// Two groups:
/// - **App settings** (Utilities → App settings, as the original):
///   [showProgressDialog].
/// - **Developer-tools overrides** (Utilities → Developer tools → SDK
///   settings): server, account, timeouts, PBS debug, privacy, ... These are
///   extras of the Flutter example. A setter that receives the default value
///   removes its key, so only values the user actually changed are stored —
///   and [applyToSdk] at startup applies only stored values. With nothing
///   changed, the app starts exactly like the original (§5 of the spec).
class AppSettings {
  // App settings (original key name).
  static const _keyShowProgressDialog = 'key_show_progress_dialog';

  // Developer-tools overrides.
  static const _keyServerUrl = 'pbs_server_url';
  static const _keyAccountId = 'pbs_account_id';
  static const _keyPbsDebug = 'pbs_debug_v2';
  static const _keyShareGeo = 'share_geo';
  static const _keyCoppa = 'coppa';
  static const _keyGdpr = 'gdpr';
  static const _keyGdprConsent = 'gdpr_consent';
  static const _keyLogLevel = 'log_level_v3';
  static const _keyThemeMode = 'theme_mode';
  static const _keyTimeout = 'timeout_millis';
  static const _keyCreativeTimeout = 'creative_factory_timeout';
  static const _keyCreativeTimeoutPreRender = 'creative_factory_timeout_pre';
  static const _keyFilterUncached = 'filter_out_uncached_bids';
  static const _keyEidsPlacement = 'eids_placement';
  static const _keyIncludeWinners = 'include_winners';
  static const _keyIncludeBidderKeys = 'include_bidder_keys';
  static const _keySendSharedId = 'send_shared_id';
  static const _keyAuctionSettingsId = 'auction_settings_id';
  static const _keyBidInspector = 'bid_inspector';

  /// The original's Prebid Server (`InternalTestApplication`).
  static const defaultServerUrl =
      'https://prebid-server-test-j.prebid.org/openrtb2/auction';

  /// The original's production account.
  static const defaultAccountId = '0689a263-318d-448b-a3d4-b02e8a709d9d';

  static SharedPreferences? _prefs;

  /// App theme mode (developer tools); the app listens to it.
  static final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  /// "Show Progress Dialog" (App settings); demo screens listen to it.
  static final showProgressDialogNotifier = ValueNotifier<bool>(false);

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    themeModeNotifier.value = themeMode;
    showProgressDialogNotifier.value = showProgressDialog;
  }

  // --- App settings ---

  static bool get showProgressDialog =>
      _prefs?.getBool(_keyShowProgressDialog) ?? false;

  static Future<void> setShowProgressDialog(bool v) async {
    showProgressDialogNotifier.value = v;
    await _prefs?.setBool(_keyShowProgressDialog, v);
  }

  // --- Developer-tools getters (default when not overridden) ---

  static String get serverUrl =>
      _prefs?.getString(_keyServerUrl) ?? defaultServerUrl;
  static String get accountId =>
      _prefs?.getString(_keyAccountId) ?? defaultAccountId;
  static bool get pbsDebug => _prefs?.getBool(_keyPbsDebug) ?? false;
  static bool get shareGeo => _prefs?.getBool(_keyShareGeo) ?? false;
  static bool get coppa => _prefs?.getBool(_keyCoppa) ?? false;
  static bool get gdpr => _prefs?.getBool(_keyGdpr) ?? false;
  static String get gdprConsent => _prefs?.getString(_keyGdprConsent) ?? '';

  static ThemeMode get themeMode => ThemeMode.values.firstWhere(
    (m) => m.name == _prefs?.getString(_keyThemeMode),
    orElse: () => ThemeMode.system,
  );

  /// Default `debug`, as the original (`PrebidMobile.LogLevel.DEBUG`).
  static PrebidLogLevel get logLevel => PrebidLogLevel.values.firstWhere(
    (l) => l.name == _prefs?.getString(_keyLogLevel),
    orElse: () => PrebidLogLevel.debug,
  );

  /// Bid request timeout in ms; `0` keeps the SDK default.
  static int get timeoutMillis => _prefs?.getInt(_keyTimeout) ?? 0;

  /// Creative factory timeouts in ms; `0` keeps the SDK default.
  static int get creativeFactoryTimeout =>
      _prefs?.getInt(_keyCreativeTimeout) ?? 0;
  static int get creativeFactoryTimeoutPreRender =>
      _prefs?.getInt(_keyCreativeTimeoutPreRender) ?? 0;

  static bool get filterOutUncachedBids =>
      _prefs?.getBool(_keyFilterUncached) ?? false;

  static PrebidEidsPlacement get eidsPlacement =>
      PrebidEidsPlacement.values.firstWhere(
        (p) => p.name == _prefs?.getString(_keyEidsPlacement),
        orElse: () => PrebidEidsPlacement.compatible,
      );

  static bool get includeWinners =>
      _prefs?.getBool(_keyIncludeWinners) ?? false;
  static bool get includeBidderKeys =>
      _prefs?.getBool(_keyIncludeBidderKeys) ?? false;
  static bool get sendSharedId => _prefs?.getBool(_keySendSharedId) ?? false;
  static String get auctionSettingsId =>
      _prefs?.getString(_keyAuctionSettingsId) ?? '';

  /// Whether bid requests / responses are captured for the Bid Inspector
  /// (observation only — does not change requests).
  static bool get bidInspector => _prefs?.getBool(_keyBidInspector) ?? true;

  // --- Developer-tools setters (default value ⇒ key removed) ---

  static Future<void> _setString(String key, String v, String def) async =>
      v == def || v.isEmpty ? _prefs?.remove(key) : _prefs?.setString(key, v);
  static Future<void> _setBool(String key, bool v, bool def) async =>
      v == def ? _prefs?.remove(key) : _prefs?.setBool(key, v);
  static Future<void> _setInt(String key, int v) async =>
      v <= 0 ? _prefs?.remove(key) : _prefs?.setInt(key, v);

  static Future<void> setServerUrl(String v) =>
      _setString(_keyServerUrl, v, defaultServerUrl);
  static Future<void> setAccountId(String v) =>
      _setString(_keyAccountId, v, defaultAccountId);
  static Future<void> setPbsDebug(bool v) => _setBool(_keyPbsDebug, v, false);
  static Future<void> setShareGeo(bool v) => _setBool(_keyShareGeo, v, false);
  static Future<void> setCoppa(bool v) => _setBool(_keyCoppa, v, false);
  static Future<void> setGdpr(bool v) => _setBool(_keyGdpr, v, false);
  static Future<void> setGdprConsent(String v) =>
      _setString(_keyGdprConsent, v, '');
  static Future<void> setLogLevel(PrebidLogLevel v) =>
      _setString(_keyLogLevel, v.name, PrebidLogLevel.debug.name);
  static Future<void> setThemeMode(ThemeMode v) async {
    themeModeNotifier.value = v;
    await _setString(_keyThemeMode, v.name, ThemeMode.system.name);
  }

  static Future<void> setTimeoutMillis(int v) => _setInt(_keyTimeout, v);
  static Future<void> setCreativeFactoryTimeout(int v) =>
      _setInt(_keyCreativeTimeout, v);
  static Future<void> setCreativeFactoryTimeoutPreRender(int v) =>
      _setInt(_keyCreativeTimeoutPreRender, v);
  static Future<void> setFilterOutUncachedBids(bool v) =>
      _setBool(_keyFilterUncached, v, false);
  static Future<void> setEidsPlacement(PrebidEidsPlacement v) => _setString(
    _keyEidsPlacement,
    v.name,
    PrebidEidsPlacement.compatible.name,
  );
  static Future<void> setIncludeWinners(bool v) =>
      _setBool(_keyIncludeWinners, v, false);
  static Future<void> setIncludeBidderKeys(bool v) =>
      _setBool(_keyIncludeBidderKeys, v, false);
  static Future<void> setSendSharedId(bool v) =>
      _setBool(_keySendSharedId, v, false);
  static Future<void> setAuctionSettingsId(String v) =>
      _setString(_keyAuctionSettingsId, v, '');
  static Future<void> setBidInspector(bool v) =>
      _setBool(_keyBidInspector, v, true);

  // --- Apply ---

  static bool _has(String key) => _prefs?.containsKey(key) ?? false;

  /// Pushes developer-tools overrides (except server / account, which go to
  /// `initializeSdk`) to the Prebid SDK.
  ///
  /// At startup ([all] = false) only stored (= user-changed) values are
  /// applied, plus the log level (the original sets DEBUG). The SDK settings
  /// page passes [all] = true to push every value, defaults included.
  static Future<void> applyToSdk({bool all = false}) async {
    bool use(String key) => all || _has(key);
    await PrebidMobile.setLogLevel(logLevel);
    if (use(_keyPbsDebug)) await PrebidMobile.setPbsDebug(pbsDebug);
    if (use(_keyShareGeo)) await PrebidMobile.setShareGeoLocation(shareGeo);
    if (timeoutMillis > 0) await PrebidMobile.setTimeoutMillis(timeoutMillis);
    if (creativeFactoryTimeout > 0) {
      await PrebidMobile.setCreativeFactoryTimeout(creativeFactoryTimeout);
    }
    if (creativeFactoryTimeoutPreRender > 0) {
      await PrebidMobile.setCreativeFactoryTimeoutPreRenderContent(
        creativeFactoryTimeoutPreRender,
      );
    }
    if (use(_keyFilterUncached)) {
      await PrebidMobile.setFilterOutUncachedBids(filterOutUncachedBids);
    }
    if (use(_keyEidsPlacement)) {
      await PrebidMobile.setEidsPlacement(eidsPlacement);
    }
    if (use(_keyIncludeWinners)) {
      await PrebidMobile.setIncludeWinners(includeWinners);
    }
    if (use(_keyIncludeBidderKeys)) {
      await PrebidMobile.setIncludeBidderKeys(includeBidderKeys);
    }
    if (use(_keySendSharedId)) await PrebidMobile.setSendSharedId(sendSharedId);
    if (use(_keyAuctionSettingsId)) {
      await PrebidMobile.setAuctionSettingsId(
        auctionSettingsId.isEmpty ? null : auctionSettingsId,
      );
    }
    if (use(_keyCoppa)) await PrebidTargeting.setSubjectToCOPPA(coppa);
    // GDPR: by default the IAB keys (IAB Consent Settings / "Enable GDPR")
    // drive consent, as in the original; only an explicit override here
    // calls the targeting setters.
    if (use(_keyGdpr)) {
      await PrebidTargeting.setSubjectToGDPR(gdpr);
      if (gdpr && gdprConsent.isNotEmpty) {
        await PrebidTargeting.setGDPRConsentString(gdprConsent);
      }
    }
  }

  // --- Reset ---

  /// Clears every developer-tools override (theme and app settings kept).
  static Future<void> resetDefaults() async {
    for (final key in [
      _keyServerUrl,
      _keyAccountId,
      _keyPbsDebug,
      _keyShareGeo,
      _keyCoppa,
      _keyGdpr,
      _keyGdprConsent,
      _keyLogLevel,
      _keyTimeout,
      _keyCreativeTimeout,
      _keyCreativeTimeoutPreRender,
      _keyFilterUncached,
      _keyEidsPlacement,
      _keyIncludeWinners,
      _keyIncludeBidderKeys,
      _keySendSharedId,
      _keyAuctionSettingsId,
      _keyBidInspector,
    ]) {
      await _prefs?.remove(key);
    }
  }
}
