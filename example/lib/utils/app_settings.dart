import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings persistence using SharedPreferences.
///
/// Saves and loads the demo's SDK settings across app restarts. [applyToSdk]
/// pushes them to the Prebid SDK (at startup and from the Settings page).
class AppSettings {
  static const _keyServerUrl = 'pbs_server_url';
  static const _keyAccountId = 'pbs_account_id';
  static const _keyPbsDebug = 'pbs_debug';
  static const _keyShareGeo = 'share_geo';
  static const _keyCoppa = 'coppa';
  static const _keyGdpr = 'gdpr';
  static const _keyGdprConsent = 'gdpr_consent';
  static const _keyLogLevel = 'log_level_v2';
  static const _keyDarkMode = 'dark_mode';
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
  static bool get darkMode => _prefs?.getBool(_keyDarkMode) ?? false;

  static PrebidLogLevel get logLevel =>
      PrebidLogLevel.values[_prefs?.getInt(_keyLogLevel) ?? 0];

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

  /// Whether bid requests / responses are captured for the Bid Inspector.
  static bool get bidInspector => _prefs?.getBool(_keyBidInspector) ?? true;

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
  static Future<void> setLogLevel(PrebidLogLevel v) async =>
      _prefs?.setInt(_keyLogLevel, v.index);
  static Future<void> setDarkMode(bool v) async =>
      _prefs?.setBool(_keyDarkMode, v);
  static Future<void> setTimeoutMillis(int v) async =>
      _prefs?.setInt(_keyTimeout, v);
  static Future<void> setCreativeFactoryTimeout(int v) async =>
      _prefs?.setInt(_keyCreativeTimeout, v);
  static Future<void> setCreativeFactoryTimeoutPreRender(int v) async =>
      _prefs?.setInt(_keyCreativeTimeoutPreRender, v);
  static Future<void> setFilterOutUncachedBids(bool v) async =>
      _prefs?.setBool(_keyFilterUncached, v);
  static Future<void> setEidsPlacement(PrebidEidsPlacement v) async =>
      _prefs?.setString(_keyEidsPlacement, v.name);
  static Future<void> setIncludeWinners(bool v) async =>
      _prefs?.setBool(_keyIncludeWinners, v);
  static Future<void> setIncludeBidderKeys(bool v) async =>
      _prefs?.setBool(_keyIncludeBidderKeys, v);
  static Future<void> setSendSharedId(bool v) async =>
      _prefs?.setBool(_keySendSharedId, v);
  static Future<void> setAuctionSettingsId(String v) async =>
      _prefs?.setString(_keyAuctionSettingsId, v);
  static Future<void> setBidInspector(bool v) async =>
      _prefs?.setBool(_keyBidInspector, v);

  // --- Apply ---

  /// Pushes every persisted setting (except server / account, which go to
  /// `initializeSdk`) to the Prebid SDK.
  static Future<void> applyToSdk() async {
    await PrebidMobile.setPbsDebug(pbsDebug);
    await PrebidMobile.setLogLevel(logLevel);
    await PrebidMobile.setShareGeoLocation(shareGeo);
    if (timeoutMillis > 0) await PrebidMobile.setTimeoutMillis(timeoutMillis);
    if (creativeFactoryTimeout > 0) {
      await PrebidMobile.setCreativeFactoryTimeout(creativeFactoryTimeout);
    }
    if (creativeFactoryTimeoutPreRender > 0) {
      await PrebidMobile.setCreativeFactoryTimeoutPreRenderContent(
        creativeFactoryTimeoutPreRender,
      );
    }
    await PrebidMobile.setFilterOutUncachedBids(filterOutUncachedBids);
    await PrebidMobile.setEidsPlacement(eidsPlacement);
    await PrebidMobile.setIncludeWinners(includeWinners);
    await PrebidMobile.setIncludeBidderKeys(includeBidderKeys);
    await PrebidMobile.setSendSharedId(sendSharedId);
    await PrebidMobile.setAuctionSettingsId(
      auctionSettingsId.isEmpty ? null : auctionSettingsId,
    );
    await PrebidTargeting.setSubjectToCOPPA(coppa);
    await PrebidTargeting.setSubjectToGDPR(gdpr);
    if (gdpr && gdprConsent.isNotEmpty) {
      await PrebidTargeting.setGDPRConsentString(gdprConsent);
    }
  }

  // --- Reset ---

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
    // Dark mode is NOT reset.
  }
}
