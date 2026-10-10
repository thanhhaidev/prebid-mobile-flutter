import 'dart:ui' show Size;

import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import 'demo_item.dart';

/// The complete Examples list: the 187 items of the original
/// `DemoItemProvider.getDemoList()` (prebid-mobile-android
/// `Example/PrebidInternalTestApp`), in its exact order, with its exact labels,
/// config ids, ad unit ids and sizes (spec §2).
///
/// Groups (in order): GAM Original (19) → In-App (71) → GAM (38) → AdMob (27)
/// → MAX (26) → SDK Testing (6).
///
/// Do not add items that are not in the original. Per-item special settings
/// live in the [DemoItem] fields; screen behaviour lives in the screens.
final List<DemoItem> demoItems = List.unmodifiable([
  ..._gamOriginal,
  ..._inApp,
  ..._gamRendering,
  ..._adMob,
  ..._max,
  ..._sdkTesting,
]);

// ---------------------------------------------------------------------------
// Shared ids
// ---------------------------------------------------------------------------

const _gam = '/21808260008/';

/// Account of the "Events" cases.
const _eventsAccount = 'prebid-stored-request-enabled-events';

/// Account of the creative-factory-timeout case.
const _sdkConfigAccount = 'prebid-stored-request-sdk-config';

const _noBids = 'prebid-demo-no-bids';
const _banner320 = 'prebid-demo-banner-320-50';
const _banner300 = 'prebid-demo-banner-300-250';
const _banner728 = 'prebid-demo-banner-728-90';
const _bannerMultisize = 'prebid-demo-banner-multisize';
const _nativeStyles = 'prebid-demo-banner-native-styles';
const _displayInterstitial = 'prebid-demo-display-interstitial-320-480';
const _videoInterstitial = 'prebid-demo-video-interstitial-320-480';
const _videoInterstitialEndCardAdConfig =
    'prebid-demo-video-interstitial-320-480-with-end-card-with-ad-configuration';
const _videoRewarded = 'prebid-demo-video-rewarded-320-480';
const _videoRewardedNoEndCard =
    'prebid-demo-video-rewarded-320-480-without-end-card';
const _videoRewardedEndCardAdConfig =
    'prebid-demo-video-rewarded-320-480-with-end-card-with-ad-configuration';
const _videoOutstream = 'prebid-demo-video-outstream';
const _videoOutstreamOriginal = 'prebid-demo-video-outstream-original-api';
const _videoInterstitialOriginal =
    'prebid-demo-video-interstitial-320-480-original-api';
const _videoRewardedOriginal =
    'prebid-demo-video-rewarded-320-480-original-api';
const _customRendererBanner = 'prebid-ita-banner-320-50-meta-custom-renderer';
const _customRendererInterstitial =
    'prebid-ita-display-interstitial-320-480-meta-custom-renderer';

const _gamCustomFormat1 = '11934135';
const _gamCustomFormat2 = '11982639';

const _admobBanner = 'ca-app-pub-1875909575462531/3793078260';
const _admobInterstitial = 'ca-app-pub-1875909575462531/6393291067';
const _admobRewarded = 'ca-app-pub-1875909575462531/1908212572';
const _admobNative = 'ca-app-pub-1875909575462531/9720985924';

const _maxBanner = '2712409601eb0b64';
const _maxMrec = '0b831dee5ef00774';
const _maxInterstitial = '3c61bf5180526594';
const _maxRewarded = '4adc922f52679355';
const _maxNative = 'fa4a9d137e6f3dff';

const _s320x50 = DemoSize(320, 50);
const _s300x250 = DemoSize(300, 250);
const _s728x90 = DemoSize(728, 90);
const _s320x480 = DemoSize(320, 480);
const _min30 = DemoSize.minPercent(30, 30);
const _minSize30 = Size(30, 30);
const _multisize = [Size(728, 90)];

/// Default banner auto-refresh (`PrebidMobile.AUTO_REFRESH_DELAY_MIN`).
const _refresh = 30;

const _banner = {AdFormat.banner};
const _video = {AdFormat.video};
const _bannerVideo = {AdFormat.banner, AdFormat.video};
const _mp4 = VideoParameters(mimes: ['video/mp4']);

/// Formats of In-App / GAM / GAM Original interstitials: VIDEO when the title
/// contains "Video Interstitial" and not "MRAID 2.0", else BANNER.
Set<AdFormat> _titleRule(String label) =>
    label.contains('Video Interstitial') && !label.contains('MRAID 2.0')
    ? _video
    : _banner;

// ---------------------------------------------------------------------------
// Helpers (one per original fragment family)
// ---------------------------------------------------------------------------

DemoItem _originalBanner(
  String label,
  String configId,
  String adUnit,
  DemoSize size,
) => DemoItem(
  label: label,
  integration: DemoIntegration.original,
  category: DemoCategory.banner,
  screen: ScreenType.a1,
  configId: configId,
  adUnitId: adUnit,
  size: size,
  // BannerAdUnit adds 728x90 when the config id contains "multisize".
  additionalSizes: configId.contains('multisize') ? _multisize : null,
  refreshSeconds: _refresh,
  note:
      'BannerAdUnit + fetchDemand -> AdManagerAdView; '
      'findPrebidCreativeSize -> resize on load',
);

DemoItem _originalInterstitial(
  String label,
  String configId,
  String adUnit, {
  DemoCategory category = DemoCategory.interstitial,
}) => DemoItem(
  label: label,
  integration: DemoIntegration.original,
  category: category,
  screen: ScreenType.b1,
  configId: configId,
  adUnitId: adUnit,
  size: _s320x480,
  adFormats: _titleRule(label),
  minSizePercentage: _minSize30,
  refreshSeconds: _refresh,
  note: 'InterstitialAdUnit + fetchDemand -> AdManagerInterstitialAd.load',
);

DemoItem _inAppBanner(
  String label,
  String configId, {
  DemoCategory category = DemoCategory.banner,
  ScreenType screen = ScreenType.a1,
  DemoSize size = _s320x50,
  List<Size>? additionalSizes,
  String? accountId,
  String? appName,
  Set<DemoFlag> flags = const {},
  String? note,
}) => DemoItem(
  label: label,
  integration: DemoIntegration.inApp,
  category: category,
  screen: screen,
  configId: configId,
  size: size,
  additionalSizes: additionalSizes,
  refreshSeconds: _refresh,
  accountId: accountId,
  appName: appName,
  flags: flags,
  note: note,
);

DemoItem _inAppInterstitial(
  String label,
  String configId, {
  DemoCategory category = DemoCategory.video,
  DemoSize size = _min30,
  PrebidFullscreenControls? controls,
  Set<DemoFlag> flags = const {},
  String? note,
}) => DemoItem(
  label: label,
  integration: DemoIntegration.inApp,
  category: category,
  screen: ScreenType.b1,
  configId: configId,
  size: size,
  adFormats: _titleRule(label),
  minSizePercentage: _minSize30,
  controls: controls,
  flags: flags,
  note: note,
);

DemoItem _inAppRewarded(
  String label,
  String configId, {
  DemoSize size = _min30,
}) => DemoItem(
  label: label,
  integration: DemoIntegration.inApp,
  category: DemoCategory.video,
  screen: ScreenType.b2,
  configId: configId,
  size: size,
);

DemoItem _inAppOutstream(String label, String configId) => DemoItem(
  label: label,
  integration: DemoIntegration.inApp,
  category: DemoCategory.video,
  screen: ScreenType.a2,
  configId: configId,
  size: _s300x250,
  adFormats: _video,
  note:
      'videoPlacementType IN_BANNER; no auto-refresh; '
      'video callbacks are only logged',
);

DemoItem _inAppNative(
  String label,
  String configId, {
  ScreenType screen = ScreenType.c1,
  String? accountId,
}) => DemoItem(
  label: label,
  integration: DemoIntegration.inApp,
  category: DemoCategory.native,
  screen: screen,
  configId: configId,
  accountId: accountId,
  note: 'configureOriginalPrebid() re-init; standard native asset set',
);

DemoItem _gamBanner(
  String label,
  String configId,
  String? adUnit, {
  DemoCategory category = DemoCategory.banner,
  List<Size>? additionalSizes,
  String? accountId,
  String? note,
}) => DemoItem(
  label: label,
  integration: DemoIntegration.gam,
  category: category,
  screen: ScreenType.a1,
  configId: configId,
  adUnitId: adUnit,
  size: _s320x50,
  additionalSizes: additionalSizes,
  refreshSeconds: _refresh,
  accountId: accountId,
  note: note,
);

DemoItem _gamInterstitial(
  String label,
  String configId,
  String adUnit, {
  DemoCategory category = DemoCategory.interstitial,
}) {
  final formats = _titleRule(label);
  return DemoItem(
    label: label,
    integration: DemoIntegration.gam,
    category: category,
    screen: ScreenType.b1,
    configId: configId,
    adUnitId: adUnit,
    size: _min30,
    adFormats: formats,
    // Only display interstitials get setMinSizePercentage(30, 30).
    minSizePercentage: formats.contains(AdFormat.banner) ? _minSize30 : null,
  );
}

DemoItem _gamRewarded(String label, String configId, String adUnit) => DemoItem(
  label: label,
  integration: DemoIntegration.gam,
  category: DemoCategory.video,
  screen: ScreenType.b2,
  configId: configId,
  adUnitId: adUnit,
  size: _min30,
);

DemoItem _gamOutstream(
  String label,
  String configId,
  String adUnit, {
  ScreenType screen = ScreenType.a2,
}) => DemoItem(
  label: label,
  integration: DemoIntegration.gam,
  category: DemoCategory.video,
  screen: screen,
  configId: configId,
  adUnitId: adUnit,
  size: _s300x250,
  adFormats: _video,
  refreshSeconds: screen == ScreenType.a2 ? _refresh : null,
  note: screen == ScreenType.a2
      ? 'IN_BANNER; Stop refresh is not wired'
      : 'IN_FEED; ad every 5th row',
);

DemoItem _gamNative(
  String label,
  String configId,
  String adUnit, {
  String? customFormatId,
  String? accountId,
  ScreenType screen = ScreenType.c2,
}) => DemoItem(
  label: label,
  integration: DemoIntegration.gam,
  category: DemoCategory.native,
  screen: screen,
  configId: configId,
  adUnitId: adUnit,
  customFormatId: customFormatId,
  accountId: accountId,
);

DemoItem _adMobBanner(
  String label,
  String configId, {
  DemoSize size = _s320x50,
  List<Size>? additionalSizes,
  String? accountId,
  Set<DemoFlag> flags = const {},
}) => DemoItem(
  label: label,
  integration: DemoIntegration.adMob,
  category: DemoCategory.banner,
  screen: ScreenType.g1,
  configId: configId,
  adUnitId: _admobBanner,
  size: size,
  additionalSizes: additionalSizes,
  refreshSeconds: _refresh,
  accountId: accountId,
  flags: flags,
);

DemoItem _adMobInterstitial(
  String label,
  String? configId, {
  required bool isVideo,
  List<String>? randomConfigIds,
  Set<DemoFlag> flags = const {},
}) {
  final multi = randomConfigIds != null;
  return DemoItem(
    label: label,
    integration: DemoIntegration.adMob,
    category: isVideo || multi ? DemoCategory.video : DemoCategory.interstitial,
    screen: ScreenType.g2,
    configId: configId,
    randomConfigIds: randomConfigIds,
    adUnitId: _admobInterstitial,
    size: _s320x480,
    adFormats: multi ? _bannerVideo : (isVideo ? _video : _banner),
    // "display: minSize 30" (also the multiformat fragment).
    minSizePercentage: isVideo && !multi ? null : _minSize30,
    flags: flags,
  );
}

DemoItem _adMobRewarded(
  String label,
  String configId, {
  Set<DemoFlag> flags = const {},
}) => DemoItem(
  label: label,
  integration: DemoIntegration.adMob,
  category: DemoCategory.video,
  screen: ScreenType.g3,
  configId: configId,
  adUnitId: _admobRewarded,
  size: _s320x480,
  flags: flags,
);

DemoItem _adMobNative(String label, String configId, {String? accountId}) =>
    DemoItem(
      label: label,
      integration: DemoIntegration.adMob,
      category: DemoCategory.native,
      screen: ScreenType.g4,
      configId: configId,
      adUnitId: _admobNative,
      accountId: accountId,
      note: 'configureOriginalPrebid() re-init; AdLoader.forNativeAd',
    );

DemoItem _maxBannerItem(
  String label,
  String configId, {
  String adUnit = _maxBanner,
  DemoSize size = _s320x50,
  List<Size>? additionalSizes,
  String? accountId,
  Set<DemoFlag> flags = const {},
}) => DemoItem(
  label: label,
  integration: DemoIntegration.max,
  category: DemoCategory.banner,
  screen: ScreenType.h1,
  configId: configId,
  adUnitId: adUnit,
  size: size,
  additionalSizes: additionalSizes,
  refreshSeconds: _refresh,
  accountId: accountId,
  flags: flags,
  note: 'MaxAdView (MREC when width == 300)',
);

DemoItem _maxInterstitialItem(
  String label,
  String? configId, {
  required bool isVideo,
  List<String>? randomConfigIds,
  Set<DemoFlag> flags = const {},
}) {
  final multi = randomConfigIds != null;
  return DemoItem(
    label: label,
    integration: DemoIntegration.max,
    category: isVideo || multi ? DemoCategory.video : DemoCategory.interstitial,
    screen: ScreenType.h2,
    configId: configId,
    randomConfigIds: randomConfigIds,
    adUnitId: _maxInterstitial,
    size: _s320x480,
    adFormats: multi ? _bannerVideo : (isVideo ? _video : _banner),
    minSizePercentage: _minSize30,
    flags: flags,
  );
}

DemoItem _maxRewardedItem(
  String label,
  String configId, {
  Set<DemoFlag> flags = const {},
}) => DemoItem(
  label: label,
  integration: DemoIntegration.max,
  category: DemoCategory.video,
  screen: ScreenType.h3,
  configId: configId,
  adUnitId: _maxRewarded,
  size: _s320x480,
  flags: flags,
);

DemoItem _maxNativeItem(String label, String configId, {String? accountId}) =>
    DemoItem(
      label: label,
      integration: DemoIntegration.max,
      category: DemoCategory.native,
      screen: ScreenType.h4,
      configId: configId,
      adUnitId: _maxNative,
      accountId: accountId,
    );

// ---------------------------------------------------------------------------
// 2.1 GAM Original (addGamOriginalExamples) — #1–#19
// ---------------------------------------------------------------------------

final _gamOriginal = <DemoItem>[
  _originalBanner(
    'Banner 320x50 (GAM Original) [OK, PUC]',
    _banner320,
    '${_gam}prebid_demo_app_original_api_banner',
    _s320x50,
  ),
  _originalBanner(
    'Banner 300x250 (GAM Original) [OK, PUC]',
    _banner300,
    '${_gam}prebid_demo_app_original_api_banner_300x250_order',
    _s300x250,
  ),
  _originalBanner(
    'Banner 728x90 (GAM Original) [OK, PUC]',
    _banner728,
    '${_gam}prebid_demo_app_original_api_banner_728x90',
    _s728x90,
  ),
  _originalBanner(
    'Banner Multisize (GAM Original) [OK, PUC]',
    _bannerMultisize,
    '${_gam}prebid_demo_app_original_api_banner_multisize',
    _s320x50,
  ),
  const DemoItem(
    label: 'Banner 300x250 Multiformat (GAM) [OK, PUC]',
    integration: DemoIntegration.original,
    category: DemoCategory.banner,
    screen: ScreenType.a1,
    randomConfigIds: [_banner300, _videoOutstreamOriginal],
    adUnitId: '${_gam}prebid-demo-original-banner-multiformat',
    size: _s300x250,
    adFormats: _bannerVideo,
    videoParameters: _mp4,
    refreshSeconds: _refresh,
    note: 'BannerAdUnit(random config, {BANNER, VIDEO}), mimes video/mp4',
  ),
  _originalInterstitial(
    'Display Interstitial 320x480 (GAM Original) [OK, PUC]',
    _displayInterstitial,
    '${_gam}prebid-demo-app-original-api-display-interstitial',
  ),
  const DemoItem(
    label: 'Interstitial Multiformat 320x480 (GAM Original) [OK, PUC]',
    integration: DemoIntegration.original,
    category: DemoCategory.interstitial,
    screen: ScreenType.b1,
    randomConfigIds: [_displayInterstitial, _videoInterstitialOriginal],
    adUnitId: '${_gam}prebid-demo-intestitial-multiformat',
    size: _s320x480,
    adFormats: _bannerVideo,
    videoParameters: _mp4,
    minSizePercentage: _minSize30,
    note:
        'InterstitialAdUnit(random config, {BANNER, VIDEO}) -> '
        'AdManagerInterstitialAd',
  ),
  const DemoItem(
    label: 'Video Outstream (GAM Original) [OK, PUC]',
    integration: DemoIntegration.original,
    category: DemoCategory.video,
    screen: ScreenType.a2,
    configId: _videoOutstreamOriginal,
    adUnitId: '${_gam}prebid-demo-original-api-video-banner',
    size: _s300x250,
    adFormats: _video,
    refreshSeconds: _refresh,
    note:
        'BannerAdUnit({VIDEO}) without VideoParameters; '
        'Stop refresh is not wired',
  ),
  const DemoItem(
    label: 'Video Outstream New API (GAM Original) [OK, PUC]',
    integration: DemoIntegration.original,
    category: DemoCategory.video,
    screen: ScreenType.a2,
    configId: _videoOutstreamOriginal,
    adUnitId: '${_gam}prebid-demo-original-api-video-banner',
    size: _s300x250,
    adFormats: _video,
    refreshSeconds: _refresh,
    note: 'Identical code to "Video Outstream (GAM Original)"',
  ),
  const DemoItem(
    label: 'Instream Video (GAM Original) [OK, PUC]',
    integration: DemoIntegration.original,
    category: DemoCategory.video,
    screen: ScreenType.a2v,
    configId: '1001-1',
    adUnitId: '/5300653/test_adunit_vast_pavliuchyk',
    size: DemoSize(640, 480),
    adFormats: _video,
    accountId: '1001',
    serverUrl: 'https://prebid-server.rubiconproject.com/openrtb2/auction',
    videoParameters: VideoParameters(
      mimes: ['video/mp4'],
      protocols: [VideoProtocol.vast2_0],
      playbackMethods: [VideoPlaybackMethod.autoPlaySoundOff],
      placement: VideoPlacement.inStream,
    ),
    note:
        'fetchDemand -> GAM IMA ad tag -> ExoPlayer/IMA pre-roll '
        '(content https://storage.googleapis.com/gvabox/media/samples/'
        'stock.mp4); restores server + account on exit',
  ),
  const DemoItem(
    label: 'Instream Video New API (GAM Original) [OK, PUC]',
    integration: DemoIntegration.original,
    category: DemoCategory.video,
    screen: ScreenType.a2v,
    configId: '1001-1',
    adUnitId: '/5300653/test_adunit_vast_pavliuchyk',
    size: DemoSize(640, 480),
    adFormats: _video,
    accountId: '1001',
    serverUrl: 'https://prebid-server.rubiconproject.com/openrtb2/auction',
    videoParameters: VideoParameters(
      mimes: ['video/mp4'],
      protocols: [VideoProtocol.vast2_0],
      playbackMethods: [VideoPlaybackMethod.autoPlaySoundOff],
      placement: VideoPlacement.inStream,
      plcmt: VideoPlcmt.instream,
    ),
    flags: {DemoFlag.newApi},
    note: 'InStreamVideoAdUnit(configId, 640, 480) + plcmt InStream',
  ),
  _originalInterstitial(
    'Video Interstitial 320x480 (GAM Original) [OK, PUC]',
    _videoInterstitialOriginal,
    '${_gam}prebid-demo-app-original-api-video-interstitial',
    category: DemoCategory.video,
  ),
  const DemoItem(
    label: 'Video Rewarded 320x480 (GAM Original) [OK, PUC]',
    integration: DemoIntegration.original,
    category: DemoCategory.video,
    screen: ScreenType.b2,
    configId: _videoRewardedOriginal,
    adUnitId: '${_gam}prebid-demo-app-original-api-video-interstitial',
    size: _min30,
    note: 'RewardedVideoAdUnit + fetchDemand -> RewardedAd.load',
  ),
  const DemoItem(
    label: 'Native In-App (GAM Original) [OK, PUC]',
    integration: DemoIntegration.original,
    category: DemoCategory.native,
    screen: ScreenType.c1,
    configId: _nativeStyles,
    adUnitId: '${_gam}apollo_custom_template_native_ad_unit',
    customFormatId: _gamCustomFormat1,
    note:
        'NativeAdUnit (tracker IMAGE+JS); AdLoader banner + native + '
        'custom format 11934135 -> findNative -> render Prebid native',
  ),
  const DemoItem(
    label: 'Native Banner (GAM Original) [OK, PUC]',
    integration: DemoIntegration.original,
    category: DemoCategory.native,
    screen: ScreenType.a1,
    configId: _nativeStyles,
    adUnitId: '${_gam}prebid-demo-original-native-styles',
    refreshSeconds: _refresh,
    note:
        'NativeAdUnit (tracker IMAGE only); AdManagerAdView FLUID; '
        'findPrebidCreativeSize',
  ),
  const DemoItem(
    label: 'Multiformat (Banner + Video + In-App Native) (GAM Original)',
    integration: DemoIntegration.original,
    category: DemoCategory.banner,
    screen: ScreenType.d,
    randomConfigIds: [_banner320, _videoOutstreamOriginal, _nativeStyles],
    adUnitId: '${_gam}prebid-demo-multiformat',
    customFormatId: '12304464',
    note:
        'Random config of the enabled formats; AdLoader BANNER + '
        'MEDIUM_RECTANGLE + native + custom format 12304464 -> findNative',
  ),
  const DemoItem(
    label: 'Multiformat (Banner + Video + Native Styles) (GAM Original)',
    integration: DemoIntegration.original,
    category: DemoCategory.banner,
    screen: ScreenType.d,
    randomConfigIds: [_banner320, _videoOutstreamOriginal, _nativeStyles],
    adUnitId: '${_gam}prebid-demo-multiformat-native-styles',
    note:
        'AdManagerAdView sizes FLUID, BANNER, MEDIUM_RECTANGLE; '
        'findPrebidCreativeSize',
  ),
  const DemoItem(
    label: 'Multiformat Interstitial (Banner + Video) (GAM Original)',
    integration: DemoIntegration.original,
    category: DemoCategory.interstitial,
    screen: ScreenType.b1,
    randomConfigIds: [_displayInterstitial, _videoInterstitialOriginal],
    adUnitId: '${_gam}prebid-demo-intestitial-multiformat',
    size: _s320x480,
    adFormats: _bannerVideo,
    minSizePercentage: Size(80, 80),
    videoParameters: _mp4,
    flags: {DemoFlag.navGraphBug},
    note:
        'Intended: PrebidAdUnit + PrebidRequest(interstitial, banner '
        'minW/H% 80/80, video mp4 320x480) -> AdManagerInterstitialAd',
  ),
  const DemoItem(
    label: 'Multiformat Rewarded (GAM Original)',
    integration: DemoIntegration.original,
    category: DemoCategory.interstitial,
    screen: ScreenType.b1,
    configId: _videoRewardedOriginal,
    adUnitId: '${_gam}prebid-demo-app-original-api-video-interstitial',
    size: _s320x480,
    adFormats: _video,
    videoParameters: VideoParameters(
      mimes: ['video/mp4'],
      protocols: [VideoProtocol.vast2_0],
      playbackMethods: [VideoPlaybackMethod.autoPlaySoundOff],
    ),
    note:
        'PrebidAdUnit + PrebidRequest(rewarded, video 320x480) -> '
        'RewardedAd.load',
  ),
];

// ---------------------------------------------------------------------------
// 2.2 In-App (addInAppPbsExamples) — #20–#90
// ---------------------------------------------------------------------------

final _inApp = <DemoItem>[
  _inAppBanner('Banner 320x50 (In-App)', _banner320),
  _inAppBanner(
    'Banner 320x50 [Bid - RANDOM noBids, Ad - RESPECTIVE]',
    _banner320,
  ),
  _inAppBanner('Banner 320x50 [noBids] (In-App)', _noBids),
  _inAppBanner(
    'Banner 320x50 Events (In-App)',
    _banner320,
    accountId: _eventsAccount,
  ),
  _inAppBanner(
    'Banner 320x50 [Custom Renderer] (In-App)',
    _customRendererBanner,
    flags: {DemoFlag.customRenderer},
  ),
  _inAppBanner(
    'Banner 320x50 [Custom Renderer, PluginEventListener] (In-App)',
    _customRendererBanner,
    flags: {DemoFlag.customRenderer, DemoFlag.pluginEventListener},
  ),
  _inAppBanner('Banner 300x250 (In-App)', _banner300, size: _s300x250),
  _inAppBanner('Banner 728x90 (In-App)', _banner728, size: _s728x90),
  _inAppBanner(
    'Banner 320x50 (In-App) [Incorrect VAST]',
    'prebid-demo-banner-incorrect-vast',
  ),
  const DemoItem(
    label: 'Banner 320x50 Scrollable Reusable (In-App)',
    integration: DemoIntegration.inApp,
    category: DemoCategory.banner,
    screen: ScreenType.a3,
    configId: _banner320,
    size: _s320x50,
    note: 'No auto-load. "Load ad" loads, "Add" attaches, "Remove" detaches',
  ),
  _inAppBanner(
    'Banner 320x50 Recycler view (In-App)',
    _banner320,
    screen: ScreenType.a4,
    note:
        'List: 3 placeholders (500dp), banner, 6 placeholders, banner, '
        '1 placeholder',
  ),
  _inAppBanner(
    'Banner 320x50 Scrollable (In-App)',
    _banner320,
    screen: ScreenType.a5,
  ),
  _inAppBanner(
    'Banner 320x50 (In-App) [DeepLink+]',
    'prebid-demo-banner-deeplink',
  ),
  const DemoItem(
    label: 'Banner 320x50 Layout (In-App)',
    integration: DemoIntegration.inApp,
    category: DemoCategory.banner,
    screen: ScreenType.a6,
    size: _s320x50,
    refreshSeconds: 5,
    note:
        'BannerView declared in XML: configId prebid-demo-banner-320-50, '
        'refreshIntervalSec 5; the bundle has no config id',
  ),
  _inAppBanner(
    'Banner 320x50 Special Symbols (In-App)',
    _banner320,
    appName: '天気',
  ),
  _inAppBanner(
    'Banner Multisize (In-App)',
    _bannerMultisize,
    additionalSizes: _multisize,
  ),
  const DemoItem(
    label: 'Banners and Interstitial (In-App)',
    integration: DemoIntegration.inApp,
    category: DemoCategory.banner,
    screen: ScreenType.e,
    note:
        'Top banner (refresh 15 s) + bottom banner (refresh 60 s) '
        'prebid-demo-banner-320-50 320x50 + InterstitialAdUnit '
        'prebid-demo-display-interstitial-320-480 minSize 30 %',
  ),
  _inAppBanner(
    'MRAID 2.0: Expand - 1 Part (In-App)',
    'prebid-demo-mraid-expand-1-part',
    category: DemoCategory.mraid,
  ),
  _inAppBanner(
    'MRAID 2.0: Expand - 2 Part (In-App)',
    'prebid-demo-mraid-expand-2-part',
    category: DemoCategory.mraid,
  ),
  _inAppBanner(
    'MRAID 2.0: Resize (In-App)',
    'prebid-demo-mraid-resize',
    category: DemoCategory.mraid,
  ),
  _inAppBanner(
    'MRAID 2.0: Resize With Errors (In-App)',
    'prebid-demo-mraid-resize-with-errors',
    category: DemoCategory.mraid,
    size: const DemoSize(300, 100),
  ),
  _inAppBanner(
    'MRAID 2.0: Fullscreen (In-App)',
    'prebid-demo-mraid-fullscreen',
    category: DemoCategory.mraid,
    size: _s320x480,
  ),
  _inAppInterstitial(
    'MRAID 2.0: Video Interstitial (In-App)',
    'prebid-demo-mraid-video-interstitial',
    category: DemoCategory.mraid,
  ),
  _inAppBanner(
    'MRAID 3.0: Viewability Compliance Ad (In-App)',
    'prebid-demo-mraid-viewability-compliance',
    category: DemoCategory.mraid,
    size: _s320x480,
  ),
  _inAppBanner(
    'MRAID 3.0: Resize Negative Test (In-App)',
    'prebid-demo-mraid-resize-negative-test',
    category: DemoCategory.mraid,
    size: _s320x480,
  ),
  _inAppBanner(
    'MRAID 3.0: Load And Events (In-App)',
    'prebid-demo-mraid-load-and-events',
    category: DemoCategory.mraid,
  ),
  _inAppBanner(
    'MRAID OX: Test Properties 3.0 (In-App)',
    'prebid-demo-mraid-test-properties-3',
    category: DemoCategory.mraid,
  ),
  _inAppBanner(
    'MRAID OX: Test Methods 3.0 (In-App)',
    'prebid-demo-mraid-test-methods-3',
    category: DemoCategory.mraid,
  ),
  _inAppBanner(
    'MRAID OX: Resize (With Scroll) (In-App)',
    'prebid-demo-mraid-resize',
    category: DemoCategory.mraid,
    screen: ScreenType.a5,
  ),
  _inAppBanner(
    'MRAID OX: Resize (Expandable) (In-App)',
    'prebid-demo-mraid-resize-expandable',
    category: DemoCategory.mraid,
  ),
  _inAppInterstitial(
    'Display Interstitial 320x480 (In-App)',
    _displayInterstitial,
    category: DemoCategory.interstitial,
  ),
  _inAppInterstitial(
    'Display Interstitial 320x480 [noBids] (In-App)',
    _noBids,
    category: DemoCategory.interstitial,
  ),
  _inAppInterstitial('Video Interstitial 320x480 (In-App)', _videoInterstitial),
  _inAppInterstitial('Video Interstitial 320x480 (In-App) [noBids]', _noBids),
  _inAppInterstitial(
    'Video Interstitial 320x480 SkipOffset (In-App)',
    'prebid-demo-video-interstitial-320-480-skip-offset',
  ),
  _inAppInterstitial(
    'Video Interstitial 320x480 Deeplink+ (In-App)',
    'prebid-demo-video-interstitial-320-480-deeplink',
  ),
  _inAppInterstitial(
    'Video Interstitial 320x480 With End Card (In-App)',
    'prebid-demo-video-interstitial-320-480-with-end-card',
  ),
  _inAppInterstitial(
    'Video Interstitial 320x480 With Close Button (In-App)',
    _videoInterstitial,
    controls: const PrebidFullscreenControls(
      closeButtonArea: 0.40,
      closeButtonPosition: PrebidButtonPosition.topLeft,
    ),
  ),
  _inAppInterstitial(
    'Video Interstitial 320x480 With End Card and Sound Button (In-App)',
    'prebid-demo-video-interstitial-320-480-with-end-card',
    controls: const PrebidFullscreenControls(
      isMuted: false,
      isSoundButtonVisible: true,
    ),
  ),
  _inAppInterstitial(
    'Video Interstitial 320x480 With End Card and Skip Button (In-App)',
    'prebid-demo-video-interstitial-320-480-with-end-card',
    controls: const PrebidFullscreenControls(
      skipDelay: 5,
      skipButtonArea: 0.30,
      skipButtonPosition: PrebidButtonPosition.topLeft,
    ),
  ),
  _inAppInterstitial(
    'Video Interstitial 320x480 with MRAID End Card (In-App)',
    'prebid-demo-video-interstitial-mraid-end-card',
    category: DemoCategory.mraid,
  ),
  _inAppInterstitial(
    'Video Interstitial 320x480 With Ad Configuration (In-App)',
    'prebid-demo-video-interstitial-320-480-with-ad-configuration',
    size: _s320x480,
  ),
  _inAppInterstitial(
    'Video Interstitial 320x480 With End Card With Ad Configuration (In-App)',
    _videoInterstitialEndCardAdConfig,
    size: _s320x480,
  ),
  _inAppInterstitial(
    'Video Interstitial Vertical With End Card (In-App)',
    'prebid-demo-video-interstitial-vertical-with-end-card',
  ),
  _inAppInterstitial(
    'Video Interstitial Landscape With End Card (In-App)',
    'prebid-demo-video-interstitial-vertical-with-end-card',
  ),
  const DemoItem(
    label: 'Multiformat Interstitial 320x480 (In-App)',
    integration: DemoIntegration.inApp,
    category: DemoCategory.interstitial,
    screen: ScreenType.b1,
    randomConfigIds: [_displayInterstitial, _videoInterstitial],
    size: _min30,
    adFormats: _bannerVideo,
    minSizePercentage: _minSize30,
  ),
  _inAppInterstitial(
    'Display Interstitial 320x480 [Custom Renderer] (In-App)',
    _customRendererInterstitial,
    category: DemoCategory.interstitial,
    flags: {DemoFlag.customRenderer},
    note: 'SampleCustomRenderer: AlertDialog interstitial with a WebView',
  ),
  _inAppInterstitial(
    'Display Interstitial 320x480 [Custom Renderer, PluginEventListener] '
    '(In-App)',
    _customRendererInterstitial,
    category: DemoCategory.interstitial,
    flags: {DemoFlag.customRenderer, DemoFlag.pluginEventListener},
  ),
  _inAppRewarded(
    'Video Rewarded 320x480 without End Card (In-App)',
    _videoRewardedNoEndCard,
  ),
  _inAppRewarded(
    'Video Rewarded 320x480 with End Card (In-App) [noBids]',
    _noBids,
  ),
  _inAppRewarded('Video Rewarded 320x480 (In-App)', _videoRewarded),
  _inAppRewarded(
    'Video Rewarded 320x480 With Ad Configuration (In-App)',
    _videoRewardedEndCardAdConfig,
  ),
  _inAppOutstream('Video Outstream (In-App)', _videoOutstream),
  const DemoItem(
    label: 'Multiformat Banner 300x250 (In-App)',
    integration: DemoIntegration.inApp,
    category: DemoCategory.video,
    screen: ScreenType.a2,
    randomConfigIds: [_banner300, _videoOutstream],
    size: _s300x250,
    adFormats: _bannerVideo,
    refreshSeconds: _refresh,
    note: 'BannerView(random config) {BANNER, VIDEO}, IN_BANNER',
  ),
  _inAppOutstream('Video Outstream [noBids] (In-App)', _noBids),
  const DemoItem(
    label: 'Video Outstream Feed (In-App)',
    integration: DemoIntegration.inApp,
    category: DemoCategory.video,
    screen: ScreenType.f,
    configId: _videoOutstream,
    size: _s300x250,
    adFormats: _video,
    note: 'Endless list; ad (IN_FEED) where pos % 5 == 0 && pos != 0',
  ),
  _inAppOutstream(
    'Video Outstream with End Card (In-App)',
    'prebid-demo-video-outstream-with-end-card',
  ),
  _inAppRewarded(
    'Display Rewarded 320x480 (5s to reward + 3s postreward + autoclose)',
    'prebid-demo-banner-rewarded-time',
    size: _s320x480,
  ),
  _inAppRewarded(
    'Display Rewarded 320x480 (click for url event + 3s postreward + close '
        'button)',
    'prebid-demo-banner-rewarded-event',
    size: _s320x480,
  ),
  _inAppRewarded(
    'Display Rewarded 320x480 (Default)',
    'prebid-demo-banner-rewarded-default',
    size: _s320x480,
  ),
  _inAppRewarded(
    'Video Rewarded 320x480 (3s to reward + 3s postreward + autoclose)',
    'prebid-demo-video-rewarded-time',
    size: _s320x480,
  ),
  _inAppRewarded(
    'Video Rewarded 320x480 (midpoint + 2s postreward + close button)',
    'prebid-demo-video-rewarded-playbackevent',
    size: _s320x480,
  ),
  _inAppRewarded(
    'Video Rewarded 320x480 (Default)',
    'prebid-demo-video-rewarded-default',
    size: _s320x480,
  ),
  _inAppRewarded(
    'Video Rewarded Endcard 320x480 (5s to reward + 3s postreward + '
        'autoclose)',
    'prebid-demo-video-rewarded-endcard-time',
    size: _s320x480,
  ),
  _inAppRewarded(
    'Video Rewarded Endcard 320x480 (click for url event + 3s postreward + '
        'close button)',
    'prebid-demo-video-rewarded-endcard-event',
    size: _s320x480,
  ),
  _inAppRewarded(
    'Video Rewarded Endcard 320x480 (Default)',
    'prebid-demo-video-rewarded-endcard-default',
    size: _s320x480,
  ),
  _inAppNative('Native Ad (In-App)', _nativeStyles),
  _inAppNative('Native Ad Feed (In-App)', _nativeStyles, screen: ScreenType.f),
  _inAppNative(
    'Native Ad Links (In-App)',
    'prebid-demo-native-links',
    screen: ScreenType.c3,
  ),
  _inAppNative(
    'Native Ad Events (In-App)',
    _nativeStyles,
    accountId: _eventsAccount,
  ),
  _inAppBanner(
    'Banner 320x50 Server-Side Creative Factory Timeout (In-App)',
    _banner320,
    accountId: _sdkConfigAccount,
    flags: {DemoFlag.creativeFactoryTimeoutCheck},
    note:
        'onAdLoaded is reported as onAdFailed when '
        'getCreativeFactoryTimeout() == 6000 or '
        'getCreativeFactoryTimeoutPreRenderContent() == 30000',
  ),
];

// ---------------------------------------------------------------------------
// 2.3 GAM rendering (addGamPbsExamples) — #91–#128
// ---------------------------------------------------------------------------

final _gamRendering = <DemoItem>[
  _gamBanner(
    'Banner 320x50 (GAM) [OK, AppEvent]',
    _banner320,
    '${_gam}prebid_oxb_320x50_banner',
  ),
  _gamBanner(
    'Banner 320x50 (GAM) [noBids, GAM Ad]',
    _noBids,
    null,
    note: 'The original bundle has no GAM ad unit for this item',
  ),
  _gamBanner(
    'Banner 320x50 (GAM) [OK, GAM Ad]',
    _banner320,
    '${_gam}prebid_oxb_320x50_banner_static',
  ),
  _gamBanner(
    'Banner 320x50 (GAM) [OK, Random]',
    _banner320,
    '${_gam}prebid_oxb_320x50_banner_random',
  ),
  _gamBanner(
    'Banner 320x50 Events (GAM) [OK, AppEvent]',
    _banner320,
    '${_gam}prebid_oxb_320x50_banner',
    accountId: _eventsAccount,
  ),
  const DemoItem(
    label: 'Banner 300x250 (GAM)',
    integration: DemoIntegration.gam,
    category: DemoCategory.banner,
    screen: ScreenType.a1,
    configId: _banner300,
    adUnitId: '${_gam}prebid_oxb_300x250_banner',
    size: _s300x250,
    refreshSeconds: _refresh,
  ),
  const DemoItem(
    label: 'Banner 728x90 (GAM)',
    integration: DemoIntegration.gam,
    category: DemoCategory.banner,
    screen: ScreenType.a1,
    configId: _banner728,
    adUnitId: '${_gam}prebid_oxb_728x90_banner',
    size: _s728x90,
    refreshSeconds: _refresh,
  ),
  _gamBanner(
    'Banner Multisize (GAM)',
    _bannerMultisize,
    '${_gam}prebid_oxb_multisize_banner',
    additionalSizes: _multisize,
    note: 'GAM sizes [w x h, 728x90]; Prebid additional size 728x90',
  ),
  const DemoItem(
    label: 'Banners and Interstitial (GAM) [OK, AppEvent]',
    integration: DemoIntegration.gam,
    category: DemoCategory.banner,
    screen: ScreenType.e,
    note:
        'As the In-App variant with GamBannerEventHandler '
        '"/21808260008/prebid_oxb_320x50_banner" and '
        'GamInterstitialEventHandler "/21808260008/prebid_oxb_html_interstitial"',
  ),
  _gamBanner(
    'MRAID 2.0: Expand - 1 Part (GAM)',
    'prebid-demo-mraid-expand-1-part',
    '${_gam}prebid_oxb_320x50_banner',
    category: DemoCategory.mraid,
  ),
  _gamBanner(
    'MRAID 2.0: Resize (GAM)',
    'prebid-demo-mraid-resize',
    '${_gam}prebid_oxb_320x50_banner',
    category: DemoCategory.mraid,
  ),
  _gamInterstitial(
    'MRAID 2.0: Video Interstitial (GAM)',
    'prebid-demo-mraid-video-interstitial',
    '${_gam}prebid_oxb_html_interstitial',
    category: DemoCategory.mraid,
  ),
  _gamInterstitial(
    'Display Interstitial 320x480 (GAM) [OK, AppEvent]',
    _displayInterstitial,
    '${_gam}prebid_oxb_html_interstitial',
  ),
  _gamInterstitial(
    'Display Interstitial 320x480 (GAM) [OK, Random]',
    _displayInterstitial,
    '${_gam}prebid_oxb_html_interstitial_random',
  ),
  _gamInterstitial(
    'Display Interstitial 320x480 (GAM) [noBids, GAM Ad]',
    _noBids,
    '${_gam}prebid_oxb_320x480_html_interstitial_static',
  ),
  _gamInterstitial(
    'Video Interstitial 320x480 (GAM) [OK, AppEvent]',
    _videoInterstitial,
    '${_gam}prebid_oxb_interstitial_video',
    category: DemoCategory.video,
  ),
  _gamInterstitial(
    'Video Interstitial 320x480 (GAM) [OK, Random]',
    _videoInterstitial,
    '${_gam}prebid_oxb_320x480_interstitial_video_random',
    category: DemoCategory.video,
  ),
  _gamInterstitial(
    'Video Interstitial 320x480 (GAM) [noBids, GAM Ad]',
    _noBids,
    '${_gam}prebid_oxb_320x480_interstitial_video_static',
    category: DemoCategory.video,
  ),
  _gamInterstitial(
    'Video Interstitial 320x480 With Ad Configuration (GAM) [OK, AppEvent]',
    _videoInterstitial,
    '${_gam}prebid_oxb_interstitial_video',
    category: DemoCategory.video,
  ),
  _gamInterstitial(
    'Video Interstitial 320x480 With End Card And Ad Configuration (GAM) '
        '[OK, AppEvent]',
    _videoInterstitialEndCardAdConfig,
    '${_gam}prebid_oxb_interstitial_video',
    category: DemoCategory.video,
  ),
  const DemoItem(
    label: 'Multiformat Interstitial 320x480 (GAM) [OK, AppEvent]',
    integration: DemoIntegration.gam,
    category: DemoCategory.video,
    screen: ScreenType.b1,
    randomConfigIds: [_displayInterstitial, _videoInterstitial],
    adUnitId: '${_gam}prebid_oxb_interstitial_video',
    size: _min30,
    adFormats: _bannerVideo,
    minSizePercentage: _minSize30,
  ),
  _gamRewarded(
    'Video Rewarded 320x480 without End Card (GAM) [OK, Metadata]',
    _videoRewardedNoEndCard,
    '${_gam}prebid_oxb_rewarded_video_test',
  ),
  _gamRewarded(
    'Video Rewarded 320x480 (GAM) [OK, Metadata]',
    _videoRewarded,
    '${_gam}prebid_oxb_rewarded_video_test',
  ),
  _gamRewarded(
    'Video Rewarded 320x480 (GAM) [noBids, GAM Ad]',
    _noBids,
    '${_gam}prebid_oxb_rewarded_video_static',
  ),
  _gamRewarded(
    'Video Rewarded 320x480 (GAM) [OK, Random]',
    _videoRewarded,
    '${_gam}prebid_oxb_rewarded_video_random',
  ),
  _gamRewarded(
    // Sic: no space before "(GAM)" in the original.
    'Video Rewarded 320x480 With End Card And Ad Configuration(GAM) '
        '[OK, Metadata]',
    _videoRewardedEndCardAdConfig,
    '${_gam}prebid_oxb_rewarded_video_test',
  ),
  _gamOutstream(
    'Video Outstream (GAM) [OK, AppEvent]',
    _videoOutstream,
    '${_gam}prebid_oxb_300x250_banner',
  ),
  _gamOutstream(
    'Video Outstream (GAM) [noBids, GAM Ad]',
    _noBids,
    '${_gam}prebid_oxb_outsream_video',
  ),
  _gamOutstream(
    'Video Outstream (GAM) [OK, Random]',
    _videoOutstream,
    '${_gam}prebid_oxb_outstream_video_reandom',
  ),
  _gamOutstream(
    'Video Outstream Feed (GAM)',
    _videoOutstream,
    '${_gam}prebid_oxb_outstream_video_reandom',
    screen: ScreenType.f,
  ),
  _gamNative(
    'Native Ad Custom Templates (GAM) [OK, NativeAd]',
    _nativeStyles,
    '${_gam}apollo_custom_template_native_ad_unit',
    customFormatId: _gamCustomFormat1,
  ),
  _gamNative(
    'Native Ad (GAM) [OK, GADNativeCustomTemplateAd]',
    _nativeStyles,
    '${_gam}apollo_custom_template_native_ad_unit',
    customFormatId: _gamCustomFormat2,
  ),
  _gamNative(
    'Native Ad Custom Templates Events (GAM) [OK, NativeAd]',
    _nativeStyles,
    '${_gam}apollo_custom_template_native_ad_unit',
    customFormatId: _gamCustomFormat1,
    accountId: _eventsAccount,
  ),
  _gamNative(
    'Native Ad (GAM) [noBids, GADNativeCustomTemplateAd]',
    _noBids,
    '${_gam}apollo_custom_template_native_ad_unit',
    customFormatId: _gamCustomFormat2,
  ),
  _gamNative(
    'Native Ad Unified Ad (GAM) [OK, NativeAd]',
    _nativeStyles,
    '${_gam}unified_native_ad_unit',
  ),
  _gamNative(
    'Native Ad (GAM) [OK, GADUnifiedNativeAd]',
    _nativeStyles,
    '${_gam}unified_native_ad_unit_static',
  ),
  _gamNative(
    'Native Ad (GAM) [noBids, GADUnifiedNativeAd]',
    _noBids,
    '${_gam}unified_native_ad_unit_static',
  ),
  _gamNative(
    'Native Ad Feed (GAM) [OK, NativeAd]',
    _nativeStyles,
    '${_gam}apollo_custom_template_native_ad_unit',
    customFormatId: _gamCustomFormat1,
    screen: ScreenType.f,
  ),
];

// ---------------------------------------------------------------------------
// 2.4 AdMob (addAdMobPbsExamples) — #129–#155
// ---------------------------------------------------------------------------

final _adMob = <DemoItem>[
  _adMobBanner('Banner 320x50 (AdMob) [OK, OXB Adapter]', _banner320),
  _adMobBanner('Banner 320x50 (AdMob) [OK, Random]', _banner320),
  _adMobBanner('Banner 320x50 (AdMob) [noBids, AdMob ad]', _noBids),
  _adMobBanner(
    'Banner 320x50 (AdMob) [Random, Respectively]',
    _banner320,
    flags: {DemoFlag.randomBidDrop},
  ),
  _adMobBanner(
    'Banner 320x50 Events (AdMob) [OK, OXB Adapter]',
    _banner320,
    accountId: _eventsAccount,
  ),
  _adMobBanner(
    'Banner 320x50 (AdMob, Custom Renderer)',
    _customRendererBanner,
    flags: {DemoFlag.customRenderer},
  ),
  _adMobBanner(
    'Banner 300x250 (AdMob) [OK, OXB Adapter]',
    _banner300,
    size: _s300x250,
  ),
  _adMobBanner(
    'Banner 300x250 (AdMob) [OK, Random]',
    _banner300,
    size: _s300x250,
  ),
  _adMobBanner(
    'Banner Adaptive (AdMob) [OK, Random]',
    _bannerMultisize,
    additionalSizes: _multisize,
    flags: {DemoFlag.adaptiveBanner},
  ),
  _adMobInterstitial(
    'Video Interstitial 320x480 (AdMob) [OK, OXB Adapter]',
    _videoInterstitial,
    isVideo: true,
  ),
  _adMobInterstitial(
    'Display Interstitial 320x480 (AdMob, Custom Renderer)',
    _customRendererInterstitial,
    isVideo: false,
    flags: {DemoFlag.customRenderer},
  ),
  _adMobInterstitial(
    'Video Interstitial 320x480 (AdMob) [noBids, AdMob ad]',
    _noBids,
    isVideo: true,
  ),
  _adMobInterstitial(
    'Video Interstitial 320x480 (AdMob) [OK, Random]',
    _videoInterstitial,
    isVideo: true,
    flags: {DemoFlag.randomBidDrop},
  ),
  _adMobInterstitial(
    'Video Interstitial With Ad Configuration 320x480 (AdMob) '
    '[OK, OXB Adapter]',
    _videoInterstitial,
    isVideo: true,
  ),
  _adMobInterstitial(
    'Video Interstitial With End Card And Ad Configuration 320x480 (AdMob) '
    '[OK, OXB Adapter]',
    _videoInterstitialEndCardAdConfig,
    isVideo: true,
  ),
  _adMobInterstitial(
    'Multiformat Interstitial 320x480 (AdMob) [OK, OXB Adapter]',
    null,
    isVideo: false,
    randomConfigIds: [_displayInterstitial, _videoInterstitial],
  ),
  _adMobRewarded(
    'Video Rewarded 320x480 (AdMob) [OK, OXB Adapter]',
    _videoRewarded,
  ),
  _adMobRewarded('Video Rewarded 320x480 (AdMob) [noBids, AdMob ad]', _noBids),
  _adMobRewarded(
    'Video Rewarded 320x480 no EndCard (AdMob) [OK, OXB Adapter]',
    _videoRewardedNoEndCard,
  ),
  _adMobRewarded(
    'Video Rewarded 320x480 (AdMob) [OK, Random]',
    _videoRewarded,
    flags: {DemoFlag.randomBidDrop},
  ),
  _adMobRewarded(
    'Video Rewarded 320x480 With Ad Configuration (AdMob) [OK, OXB Adapter]',
    _videoRewarded,
  ),
  _adMobInterstitial(
    'Display Interstitial 320x480 (AdMob) [OK, OXB Adapter]',
    _displayInterstitial,
    isVideo: false,
  ),
  _adMobInterstitial(
    'Display Interstitial 320x480 (AdMob) [noBids, AdMob Ad]',
    _noBids,
    isVideo: false,
  ),
  _adMobInterstitial(
    'Display Interstitial 320x480 (AdMob) [OK, Random]',
    _displayInterstitial,
    isVideo: false,
    flags: {DemoFlag.randomBidDrop},
  ),
  _adMobNative('Native Ad (AdMob) [OK, OXB Adapter]', _nativeStyles),
  _adMobNative('Native Ad (AdMob) [noBids, AdMob ad]', _noBids),
  _adMobNative(
    'Native Ad Events (AdMob) [OK, OXB Adapter]',
    _nativeStyles,
    accountId: _eventsAccount,
  ),
];

// ---------------------------------------------------------------------------
// 2.5 AppLovin MAX (addApplovinMaxPbsExamples) — #156–#181
// ---------------------------------------------------------------------------

final _max = <DemoItem>[
  _maxBannerItem('Banner 320x50 (MAX) [OK, Adapter]', _banner320),
  _maxBannerItem(
    'Banner 320x50 (MAX, Custom Renderer)',
    _customRendererBanner,
    flags: {DemoFlag.customRenderer},
  ),
  _maxBannerItem('Banner 320x50 (MAX) [noBids, MAX ad]', _noBids),
  _maxBannerItem(
    'Banner 320x50 (MAX) [Random, Respectively]',
    _banner320,
    flags: {DemoFlag.randomBidDrop},
  ),
  _maxBannerItem(
    'Banner 320x50 Events (MAX) [OK, Adapter]',
    _banner320,
    accountId: _eventsAccount,
  ),
  _maxBannerItem(
    'Banner 300x250 (MAX) [OK, Adapter]',
    _banner300,
    adUnit: _maxMrec,
    size: _s300x250,
  ),
  _maxBannerItem(
    'Banner 300x250 (MAX) [noBids, MAX ad]',
    _noBids,
    adUnit: _maxMrec,
    size: _s300x250,
  ),
  _maxBannerItem(
    'Banner adaptive banners (MAX) [OK, Adapter]',
    _banner320,
    additionalSizes: _multisize,
    flags: {DemoFlag.adaptiveBanner},
  ),
  _maxInterstitialItem(
    'Display Interstitial 320x480 (MAX) [OK, Adapter]',
    _displayInterstitial,
    isVideo: false,
  ),
  _maxInterstitialItem(
    'Display Interstitial 320x480 (MAX, Custom Renderer)',
    _customRendererInterstitial,
    isVideo: false,
    flags: {DemoFlag.customRenderer},
  ),
  _maxInterstitialItem(
    'Display Interstitial 320x480 (MAX) [noBids, MAX ad]',
    _noBids,
    isVideo: false,
  ),
  _maxInterstitialItem(
    'Display Interstitial 320x480 (MAX) [OK, Random]',
    _displayInterstitial,
    isVideo: false,
    flags: {DemoFlag.randomBidDrop},
  ),
  _maxInterstitialItem(
    'Video Interstitial 320x480 (MAX) [OK, Adapter]',
    _videoInterstitial,
    isVideo: true,
  ),
  _maxInterstitialItem(
    'Video Interstitial 320x480 (MAX) [noBids, MAX ad]',
    _noBids,
    isVideo: true,
  ),
  _maxInterstitialItem(
    'Video Interstitial 320x480 (MAX) [OK, Random]',
    _videoInterstitial,
    isVideo: true,
    flags: {DemoFlag.randomBidDrop},
  ),
  _maxInterstitialItem(
    'Video Interstitial 320x480 With Ad Configuration (MAX) [OK, Adapter]',
    _videoInterstitial,
    isVideo: true,
  ),
  _maxInterstitialItem(
    'Video Interstitial 320x480 With End Card And Ad Configuration (MAX) '
    '[OK, Adapter]',
    _videoInterstitialEndCardAdConfig,
    isVideo: true,
  ),
  _maxInterstitialItem(
    'Multiformat Interstitial 320x480 (MAX) [OK, Adapter]',
    null,
    isVideo: false,
    randomConfigIds: [_displayInterstitial, _videoInterstitial],
  ),
  _maxRewardedItem(
    'Video Rewarded 320x480 (MAX) [OK, Adapter]',
    _videoRewardedNoEndCard,
  ),
  _maxRewardedItem('Video Rewarded 320x480 (MAX) [noBids, MAX ad]', _noBids),
  _maxRewardedItem(
    'Video Rewarded 320x480 (MAX) [OK, Random]',
    _videoRewardedNoEndCard,
    flags: {DemoFlag.randomBidDrop},
  ),
  _maxRewardedItem(
    'Video Rewarded 320x480 no EndCard (MAX) [OK, Adapter]',
    _videoRewarded,
  ),
  _maxRewardedItem(
    'Video Rewarded With End Card And Ad Configuration 320x480 (MAX) '
    '[OK, Adapter]',
    _videoRewardedEndCardAdConfig,
  ),
  _maxNativeItem('Native Ad (MAX) [OK, Adapter]', _nativeStyles),
  _maxNativeItem('Native Ad (MAX) [noBids, MAX ad]', _noBids),
  _maxNativeItem(
    'Native Ad Events (MAX) [OK, Adapter]',
    _nativeStyles,
    accountId: _eventsAccount,
  ),
];

// ---------------------------------------------------------------------------
// 2.6 SDK Testing (addSdkTestingExamples) — #182–#187
// ---------------------------------------------------------------------------

final _sdkTesting = <DemoItem>[
  const DemoItem(
    label: 'SDK Testing: Prebid Universal Creative (WebView)',
    integration: DemoIntegration.inApp,
    category: DemoCategory.banner,
    screen: ScreenType.t,
    note: 'IP address field + "Open URL" -> WebView (JS on) loads http://<ip>',
  ),
  const DemoItem(
    label: 'SDK Testing: Prebid Universal Creative (GAM)',
    integration: DemoIntegration.inApp,
    category: DemoCategory.banner,
    screen: ScreenType.t,
    adUnitId: '${_gam}prebid_puc_testing',
    size: _s300x250,
    note:
        'AdManagerAdView 300x250 loaded on open (no Prebid); on fail '
        'toast "Error loading GAM ad: <msg>"',
  ),
  _inAppInterstitial(
    'SDK Testing: Rendering API Display Interstitial Memory Leak',
    _displayInterstitial,
    category: DemoCategory.interstitial,
    flags: {DemoFlag.memoryLeak},
    note: 'Auto-shows on load; no buttons wired',
  ),
  _inAppInterstitial(
    'SDK Testing: Rendering API Video Interstitial Memory Leak',
    _videoInterstitial,
    flags: {DemoFlag.memoryLeak},
    note: 'Auto-shows on load; no buttons wired',
  ),
  _inAppBanner(
    'SDK Testing: Rendering API Banner Memory Leak',
    _banner320,
    flags: {DemoFlag.memoryLeak},
    note: 'BannerView with an anonymous listener; no event rows fire',
  ),
  const DemoItem(
    label: 'SDK Testing: Original API Banner Memory Leak',
    integration: DemoIntegration.original,
    category: DemoCategory.banner,
    screen: ScreenType.a1,
    configId: _banner320,
    adUnitId: '${_gam}prebid_demo_app_original_api_banner',
    size: _s320x50,
    refreshSeconds: _refresh,
    flags: {DemoFlag.memoryLeak},
    note: 'BannerAdUnit fetchDemand with an empty callback; no GAM view',
  ),
];
