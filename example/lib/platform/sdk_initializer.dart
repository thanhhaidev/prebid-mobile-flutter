import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/foundation.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../utils/app_settings.dart';
import '../utils/bid_inspector.dart';
import '../utils/logger.dart';
import 'iab_consent_store.dart';
import 'pending_api.dart';

/// App start-up, in the order of the original `InternalTestApplication`
/// (spec §5):
///
/// 1. `setPrebidServerAccountId(0689a263-…)`,
/// 2. log level DEBUG,
/// 3. `initializeSdk("https://prebid-server-test-j.prebid.org/openrtb2/auction")`
///    — no PBS debug, timeouts, geo, COPPA (SDK defaults),
/// 4. KeepSettings check of the IAB consent store,
/// 5. AppLovin MAX SDK (mediation provider "max" is set by the applovin_max
///    plugin), verbose logging off.
///
/// Google Mobile Ads is not initialized at start-up (the original only does
/// it on the Versions screen). Developer-tools overrides apply only when the
/// user changed them ([AppSettings.applyToSdk]).
abstract final class SdkInitializer {
  /// AppLovin SDK key of the original (`applovin.sdk.key` in its manifest).
  static const appLovinSdkKey =
      '1tLUnP4cVQqpHuHH2yMtfdESvvUhTB05NdbCoDTceDDNVnhd_T8kwIzXDN9iwbdULTboByF-TtNaiTmsoVbxZw';

  /// Last Prebid initialization result, for the developer tools.
  static final status = ValueNotifier<String>('Initializing…');

  static Future<void> run() async {
    final log = PrebidDemoLogger.instance;
    await PendingApi.setPrebidServerAccountId(AppSettings.accountId);
    await AppSettings.applyToSdk();
    await BidInspector.instance.setEnabled(AppSettings.bidInspector);

    log.log(
      'SDK',
      'initializeSdk server=${AppSettings.serverUrl} '
          'account=${AppSettings.accountId}',
    );
    await PrebidMobile.initializeSdk(
      prebidServerUrl: AppSettings.serverUrl,
      accountId: AppSettings.accountId,
      completion: (s, error) {
        status.value = switch (s) {
          InitializationStatus.succeeded => 'Succeeded',
          InitializationStatus.serverStatusWarning => 'Server status warning',
          InitializationStatus.failed => 'Failed: ${error ?? 'unknown'}',
        };
        log.log(
          'SDK',
          'Prebid init: ${status.value}',
          level: s == InitializationStatus.failed
              ? LogLevel.error
              : LogLevel.info,
        );
      },
    );

    // KeepSettings: the original clears its ad-config settings on start when
    // the flag is off — which, as written, only removes the flag itself.
    if (!await IabConsentStore.getBool(IabConsentStore.keepSettings)) {
      await IabConsentStore.remove(IabConsentStore.keepSettings);
    }

    await _initAppLovin();
  }

  static Future<void> _initAppLovin() async {
    try {
      AppLovinMAX.setVerboseLogging(false);
      final config = await AppLovinMAX.initialize(appLovinSdkKey);
      PrebidDemoLogger.instance.log(
        'SDK',
        'AppLovin MAX initialized (${config?.countryCode ?? '?'})',
      );
    } catch (e) {
      PrebidDemoLogger.instance.log(
        'SDK',
        'AppLovin MAX init failed: $e',
        level: LogLevel.error,
      );
    }
  }
}
