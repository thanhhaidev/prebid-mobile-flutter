// One place for the plugin APIs the demo screens call around their ads:
// runtime account / server / app-name switches, the "Enable Caching" flag,
// creative-factory timeouts, the AdMob / MAX ads with their extra options,
// the "Random" bid-drop testing hook and the example's native sample
// renderer. (They were stubs while the plugin APIs were being added; the
// class keeps its name so the screens didn't change.)

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

/// Plugin calls shared by the demo screens.
abstract final class PendingApi {
  // -------------------------------------------------------------------------
  // Core: PrebidMobile
  // -------------------------------------------------------------------------

  static String? _serverUrl;

  /// `PrebidMobile.setPrebidServerAccountId` — switch account at runtime
  /// ("Events" / creative-factory cases; restored by the demo framework).
  static Future<void> setPrebidServerAccountId(String accountId) async {
    await PrebidMobile.setPrebidServerAccountId(accountId);
  }

  /// `PrebidMobile.getPrebidServerAccountId`.
  static Future<String?> getPrebidServerAccountId() async {
    return PrebidMobile.getPrebidServerAccountId();
  }

  /// `PrebidMobile.setPrebidServerUrl` — switch server at runtime (in-stream
  /// cases use the Rubicon server while open).
  static Future<void> setPrebidServerUrl(String url) async {
    _serverUrl = url;
    await PrebidMobile.setPrebidServerUrl(url);
  }

  /// The last server URL passed to [setPrebidServerUrl] (stub memory).
  static String? get lastServerUrl => _serverUrl;

  /// `PrebidMobile.setUseCacheForReportingWithRenderingApi` — the Examples
  /// screen's "Enable Caching" switch.
  static Future<void> setUseCacheForReportingWithRenderingApi(bool use) async {
    await PrebidMobile.setUseCacheForReportingWithRenderingApi(use);
  }

  /// `PrebidMobile.isUseCacheForReportingWithRenderingApi` (SDK default
  /// false) — initial state of "Enable Caching".
  static Future<bool> getUseCacheForReportingWithRenderingApi() async {
    return PrebidMobile.getUseCacheForReportingWithRenderingApi();
  }

  /// `PrebidMobile.getCreativeFactoryTimeout` (ms; SDK default 6000).
  static Future<int?> getCreativeFactoryTimeout() async {
    return PrebidMobile.getCreativeFactoryTimeout();
  }

  /// `PrebidMobile.getCreativeFactoryTimeoutPreRenderContent` (ms; SDK
  /// default 30000).
  static Future<int?> getCreativeFactoryTimeoutPreRenderContent() async {
    return PrebidMobile.getCreativeFactoryTimeoutPreRenderContent();
  }

  /// `PrebidMobile.OMSDK_VERSION` — the Versions screen. `null` = unknown.
  static Future<String?> getOmsdkVersion() async {
    return PrebidMobile.getOmsdkVersion();
  }

  /// Debug hook: probability (0..1) that the plugin drops the Prebid bid
  /// before the ad server load — the "[Random, Respectively]" / "[OK, Random]"
  /// AdMob and MAX cases use 0.5 (`BidResponseCache` pop / empty
  /// `EXTRA_RESPONSE_ID` in the original). Reset to 0 on screen exit.
  static Future<void> setDebugBidDropProbability(double probability) async {
    PrebidAdMob.debugDropBidProbability = probability;
    PrebidMax.debugDropBidProbability = probability;
  }

  static const _renderer = MethodChannel('prebid_example/custom_renderer');

  /// Registers the original's sample plugin renderer (Android
  /// `SampleCustomRenderer`, iOS `SampleRenderer`, ported into the example's
  /// native code) for a "[Custom Renderer]" screen.
  ///
  /// [withEventListener] is the "PluginEventListener" variants: the plugin
  /// owns the `BannerView` / interstitial unit, so the app can't attach a
  /// native `PluginEventListener` to it; those screens run the renderer
  /// alone (the original's listener only logs `onImpression`).
  static Future<void> registerCustomRenderer({
    bool withEventListener = false,
  }) => _renderer.invokeMethod<void>('register');

  /// Unregisters the renderer of [registerCustomRenderer] on screen exit.
  static Future<void> unregisterCustomRenderer() =>
      _renderer.invokeMethod<void>('unregister');

  // -------------------------------------------------------------------------
  // Core: PrebidTargeting
  // -------------------------------------------------------------------------

  /// `PrebidTargeting.setAppName` — "Special Symbols" case sets "天気" while
  /// open and restores `null` (the app's own name) on exit.
  static Future<void> setAppName(String? name) async {
    await PrebidTargeting.setAppName(name);
  }

  // -------------------------------------------------------------------------
  // Companions: AdMob / MAX. Screens build these ads through the helpers
  // below so the extra parameters are passed in one place once they exist.
  // -------------------------------------------------------------------------

  /// A [PrebidAdMobBannerAd] with the pending parameters.
  ///
  /// - [refreshIntervalSeconds]: `MediationBannerAdUnit.setRefreshInterval`.
  /// - [adaptive]: inline adaptive full-width banner (+ [additionalSizes]).
  static Widget adMobBanner({
    Key? key,
    required String configId,
    required String adMobAdUnitId,
    required int width,
    required int height,
    bool autoLoad = true,
    PrebidBannerAdController? controller,
    PrebidBannerAdListener? listener,
    int? refreshIntervalSeconds,
    bool adaptive = false,
    List<Size>? additionalSizes,
  }) {
    return PrebidAdMobBannerAd(
      key: key,
      configId: configId,
      adMobAdUnitId: adMobAdUnitId,
      width: width,
      height: height,
      autoLoad: autoLoad,
      controller: controller,
      listener: listener,
      refreshIntervalSeconds: refreshIntervalSeconds,
      adaptive: adaptive,
      additionalSizes: additionalSizes,
    );
  }

  /// A [PrebidMaxBannerAd] with the pending parameters and callbacks.
  ///
  /// - [refreshIntervalSeconds]: `MediationBannerAdUnit.setRefreshInterval`.
  /// - [adaptive]: adaptive MAX banner (+ [additionalSizes]).
  /// - [onAdExpanded] / [onAdCollapsed] / [onAdDisplayFailed]: MAX
  ///   `MaxAdViewAdListener` callbacks (H1 event rows).
  static Widget maxBanner({
    Key? key,
    required String configId,
    required String maxAdUnitId,
    required int width,
    required int height,
    bool autoLoad = true,
    PrebidBannerAdController? controller,
    PrebidBannerAdListener? listener,
    int? refreshIntervalSeconds,
    bool adaptive = false,
    List<Size>? additionalSizes,
    VoidCallback? onAdExpanded,
    VoidCallback? onAdCollapsed,
    void Function(String error)? onAdDisplayFailed,
  }) {
    return PrebidMaxBannerAd(
      key: key,
      configId: configId,
      maxAdUnitId: maxAdUnitId,
      width: width,
      height: height,
      autoLoad: autoLoad,
      controller: controller,
      listener: PrebidMaxBannerAdListener(
        onAdLoaded: listener?.onAdLoaded,
        onAdDisplayed: listener?.onAdDisplayed,
        onAdFailed: listener?.onAdFailed,
        onAdClicked: listener?.onAdClicked,
        onAdClosed: listener?.onAdClosed,
        onAdExpired: listener?.onAdExpired,
        onAdImpression: listener?.onAdImpression,
        onAdExpanded: onAdExpanded,
        onAdCollapsed: onAdCollapsed,
        onAdDisplayFailed: onAdDisplayFailed,
      ),
      refreshIntervalSeconds: refreshIntervalSeconds,
      adaptive: adaptive,
      additionalSizes: additionalSizes,
    );
  }

  /// A [PrebidAdMobInterstitialAd] with the pending [adFormats] (multiformat
  /// {BANNER, VIDEO}) and [minSizePercentage] parameters.
  static PrebidAdMobInterstitialAd adMobInterstitial({
    required String configId,
    required String adMobAdUnitId,
    required Set<AdFormat> adFormats,
    Size? minSizePercentage,
    PrebidFullscreenControls? controls,
    PrebidInterstitialAdListener? listener,
  }) {
    return PrebidAdMobInterstitialAd(
      configId: configId,
      adMobAdUnitId: adMobAdUnitId,
      adFormats: adFormats,
      controls: _withMinSize(controls, minSizePercentage),
      listener: listener,
    );
  }

  /// A [PrebidMaxInterstitialAd] with the pending [adFormats] and
  /// [minSizePercentage] parameters.
  static PrebidMaxInterstitialAd maxInterstitial({
    required String configId,
    required String maxAdUnitId,
    required Set<AdFormat> adFormats,
    Size? minSizePercentage,
    PrebidFullscreenControls? controls,
    PrebidInterstitialAdListener? listener,
  }) {
    return PrebidMaxInterstitialAd(
      configId: configId,
      maxAdUnitId: maxAdUnitId,
      adFormats: adFormats,
      controls: _withMinSize(controls, minSizePercentage),
      listener: listener,
    );
  }

  /// MAX native `onAdRevenuePaid` (H4 row "onAdRevenuePaid called"). Returns
  /// whether the callback could be registered.
  static bool supportsMaxNativeRevenueCallback() {
    return true;
  }

  static PrebidFullscreenControls? _withMinSize(
    PrebidFullscreenControls? c,
    Size? minSize,
  ) {
    if (minSize == null) return c;
    return PrebidFullscreenControls(
      closeButtonArea: c?.closeButtonArea,
      closeButtonPosition: c?.closeButtonPosition,
      skipButtonArea: c?.skipButtonArea,
      skipButtonPosition: c?.skipButtonPosition,
      skipDelay: c?.skipDelay,
      isMuted: c?.isMuted,
      isSoundButtonVisible: c?.isSoundButtonVisible,
      isAutoCloseOnCompletionEnabled: c?.isAutoCloseOnCompletionEnabled,
      minSizePercentage: minSize,
      supportSKOverlay: c?.supportSKOverlay,
    );
  }
}
