import 'dart:math';
import 'dart:ui' show Size;

import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart'
    show AdFormat, PrebidFullscreenControls, VideoParameters;

/// Integration filter of the Examples screen (`Tag` in the original
/// `DemoItem.kt`). Order = the segmented row order (All is appended last).
enum DemoIntegration {
  inApp('In-App'),
  gam('GAM'),
  original('Original'),
  adMob('AdMob'),
  max('Max');

  const DemoIntegration(this.label);

  /// Segment label (and the original `Tag` name).
  final String label;
}

/// Ad-category filter of the Examples screen. Order = segmented row order.
enum DemoCategory {
  banner('Banner'),
  interstitial('Interstitial'),
  mraid('MRAID'),
  video('Video'),
  native('Native');

  const DemoCategory(this.label);

  final String label;
}

/// The original's screen layouts (spec §3). [code] is the id used in the
/// spec and in [ScreenType.description].
enum ScreenType {
  a1('A1', 'Banner'),
  a2('A2', 'Outstream video banner'),
  a2v('A2v', 'In-stream video (IMA player)'),
  a3('A3', 'Reusable banner'),
  a4('A4', 'Banner in RecyclerView'),
  a5('A5', 'Scrollable banner'),
  a6('A6', 'Banner declared in layout'),
  b1('B1', 'Interstitial'),
  b2('B2', 'Rewarded'),
  c1('C1', 'In-App native'),
  c2('C2', 'GAM native'),
  c3('C3', 'Native links'),
  d('D', 'Multiformat (GAM Original)'),
  e('E', 'Banners + interstitial'),
  f('F', 'Feed'),
  g1('G1', 'AdMob banner'),
  g2('G2', 'AdMob interstitial'),
  g3('G3', 'AdMob rewarded'),
  g4('G4', 'AdMob native'),
  h1('H1', 'MAX banner'),
  h2('H2', 'MAX interstitial'),
  h3('H3', 'MAX rewarded'),
  h4('H4', 'MAX native'),
  t('T', 'Prebid Universal Creative testing');

  const ScreenType(this.code, this.description);

  final String code;
  final String description;
}

/// Which "Configure the Ad" dialog a screen shows when configuration mode is
/// on (spec §1.4).
enum ConfiguratorMode { banner, interstitial }

/// Per-item behaviours of the original fragments that are not plain data.
enum DemoFlag {
  /// `PrebidMobile.registerPluginRenderer(SampleCustomRenderer)` for the
  /// screen's lifetime (implemented later in the example's native code).
  customRenderer,

  /// Also sets a `PluginEventListener` on the ad (custom renderer cases).
  pluginEventListener,

  /// "Random" cases: randomly (50 %) drop the Prebid bid before the ad server
  /// load (`BidResponseCache` pop / empty `EXTRA_RESPONSE_ID`). Uses
  /// `PendingApi.setDebugBidDropProbability`.
  randomBidDrop,

  /// Adaptive mediation banner (AdMob inline adaptive / MAX adaptive).
  adaptiveBanner,

  /// Creative-factory-timeout check: onAdLoaded is reported as failed when the
  /// server's sdk-config was not applied (timeouts still 6000 / 30000 ms).
  creativeFactoryTimeoutCheck,

  /// SDK Testing memory-leak screen: no event rows fire; interstitials
  /// auto-show on load and have no wired button.
  memoryLeak,

  /// "New API" variant (e.g. `InStreamVideoAdUnit` + `plcmt`).
  newApi,

  /// Original nav-graph bug (#18): the destination runs the multiformat
  /// REWARDED fragment with configId "Imp id is set in another place". The
  /// registry stores the intended interstitial request.
  navGraphBug,
}

/// Size argument of a demo (`KEY_WIDTH` x `KEY_HEIGHT`).
///
/// For interstitial screens the original passes min-size percentages in the
/// same keys ([isMinSizePercentage] = true, e.g. 30 % x 30 %).
class DemoSize {
  final int width;
  final int height;
  final bool isMinSizePercentage;

  const DemoSize(this.width, this.height) : isMinSizePercentage = false;

  const DemoSize.minPercent(this.width, this.height)
    : isMinSizePercentage = true;

  /// No size (`— (0x0)` in the spec).
  static const none = DemoSize(0, 0);

  bool get isNone => width == 0 && height == 0;

  @override
  String toString() => isNone
      ? '—'
      : isMinSizePercentage
      ? 'minSize $width%x$height%'
      : '${width}x$height';
}

/// The config id that marks "no bids" in the original (`AdFragment` switches
/// account for it; no current item uses it).
const kNoBidsConfigIdLegacy = '28259226-68de-49f8-88d6-f0f2fab846e3';

/// One test case of the Examples list — mirrors `DemoItem` +
/// `createBannerBundle(...)` of `DemoItemProvider.kt`.
class DemoItem {
  /// Exact display name (also the screen title).
  final String label;

  final DemoIntegration integration;
  final DemoCategory category;

  /// Items without the `Remote` tag are hidden by the Examples filter. Every
  /// current item is remote.
  final bool remote;

  /// Which screen layout opens.
  final ScreenType screen;

  /// `KEY_CONFIG_ID`. `null` when the original passes none, or when the
  /// fragment picks one from [randomConfigIds].
  final String? configId;

  /// "(dynamic — set in fragment)": the fragment picks one at random. Use
  /// [resolveConfigId].
  final List<String>? randomConfigIds;

  /// `KEY_AD_UNIT`: GAM ad unit path, AdMob unit or MAX unit id. For screens
  /// whose fragment hard-codes its ad unit (multiformat D, PUC GAM) this
  /// holds the fragment's value.
  final String? adUnitId;

  /// `KEY_WIDTH` x `KEY_HEIGHT`.
  final DemoSize size;

  /// Additional banner sizes (multisize: 728x90).
  final List<Size>? additionalSizes;

  /// Auto-refresh in seconds, `null` = the fragment sets none.
  final int? refreshSeconds;

  /// Formats requested (banner / video / both). `null` = the ad type default
  /// (banner for banners, native for natives).
  final Set<AdFormat>? adFormats;

  /// The min-size percentage the fragment applies to an interstitial
  /// (`setMinSizePercentage`), when it applies one.
  final Size? minSizePercentage;

  /// Video parameters the fragment sets.
  final VideoParameters? videoParameters;

  /// Fullscreen controls the fragment sets (close / skip / sound buttons).
  final PrebidFullscreenControls? controls;

  /// `ARGUMENT_ACCOUNT_ID`: Prebid account used while the screen is open
  /// (restored on exit). Applied by the demo framework.
  final String? accountId;

  /// Prebid Server URL used while the screen is open (in-stream cases).
  final String? serverUrl;

  /// GAM custom native format id (`ARG_CUSTOM_FORMAT_ID`).
  final String? customFormatId;

  /// App name override while the screen is open (`AppInfoManager.setAppName`).
  final String? appName;

  final Set<DemoFlag> flags;

  /// Short behaviour note from the spec, for implementers and the placeholder.
  final String? note;

  const DemoItem({
    required this.label,
    required this.integration,
    required this.category,
    required this.screen,
    this.remote = true,
    this.configId,
    this.randomConfigIds,
    this.adUnitId,
    this.size = DemoSize.none,
    this.additionalSizes,
    this.refreshSeconds,
    this.adFormats,
    this.minSizePercentage,
    this.videoParameters,
    this.controls,
    this.accountId,
    this.serverUrl,
    this.customFormatId,
    this.appName,
    this.flags = const {},
    this.note,
  });

  bool has(DemoFlag flag) => flags.contains(flag);

  /// Whether the config id is picked by the fragment.
  bool get isDynamicConfigId => randomConfigIds != null;

  /// The config id to request: [configId], or a random one of
  /// [randomConfigIds] (as the original fragments do).
  String? resolveConfigId([Random? random]) {
    final ids = randomConfigIds;
    if (ids == null || ids.isEmpty) return configId;
    return ids[(random ?? Random()).nextInt(ids.length)];
  }

  /// "Configure the Ad" dialog mode, `null` = never shown (spec §1.4).
  ConfiguratorMode? get configuratorMode => switch (screen) {
    ScreenType.a1 ||
    ScreenType.a2 ||
    ScreenType.a2v ||
    ScreenType.a3 ||
    ScreenType.a4 ||
    ScreenType.a5 ||
    ScreenType.a6 ||
    ScreenType.d ||
    ScreenType.g1 ||
    ScreenType.g4 ||
    ScreenType.h1 ||
    ScreenType.h4 ||
    ScreenType.t => ConfiguratorMode.banner,
    ScreenType.b1 ||
    ScreenType.b2 ||
    ScreenType.g2 ||
    ScreenType.g3 ||
    ScreenType.h2 ||
    ScreenType.h3 => ConfiguratorMode.interstitial,
    // Only the video feeds have a configurator.
    ScreenType.f =>
      category == DemoCategory.video ? ConfiguratorMode.banner : null,
    ScreenType.c1 || ScreenType.c2 || ScreenType.c3 || ScreenType.e => null,
  };

  /// Whether the screen shows the `AdUnitId: <configId>` label (blank on
  /// In-App / GAM / GAM Original interstitial and rewarded screens, except
  /// the memory-leak ones; absent on natives, feeds, D, E and T).
  bool get showsAdUnitLabel => switch (screen) {
    ScreenType.b1 || ScreenType.b2 => has(DemoFlag.memoryLeak),
    ScreenType.c1 ||
    ScreenType.c2 ||
    ScreenType.c3 ||
    ScreenType.d ||
    ScreenType.e ||
    ScreenType.f ||
    ScreenType.t => false,
    _ => true,
  };

  /// Plugin APIs this item needs that are still stubbed in
  /// `lib/platform/pending_api.dart` (shown by the placeholder screen).
  List<String> get pendingApis => [
    if (accountId != null) 'setPrebidServerAccountId',
    if (serverUrl != null) 'setPrebidServerUrl',
    if (appName != null) 'PrebidTargeting.setAppName',
    if (has(DemoFlag.customRenderer)) 'custom renderer (example native code)',
    if (has(DemoFlag.randomBidDrop)) 'setDebugBidDropProbability',
    if (has(DemoFlag.adaptiveBanner)) 'adaptive mediation banner',
    if (has(DemoFlag.creativeFactoryTimeoutCheck))
      'getCreativeFactoryTimeout(PreRenderContent)',
    if ((integration == DemoIntegration.adMob ||
            integration == DemoIntegration.max) &&
        refreshSeconds != null)
      'mediation banner refreshIntervalSeconds',
    if ((screen == ScreenType.g2 || screen == ScreenType.h2) &&
        (adFormats?.length ?? 0) > 1)
      'mediation interstitial adFormats',
    if (screen == ScreenType.h1) 'MAX banner expanded/collapsed/displayFailed',
    if (screen == ScreenType.h4) 'MAX native onAdRevenuePaid',
  ];

  @override
  String toString() => 'DemoItem($label)';
}
