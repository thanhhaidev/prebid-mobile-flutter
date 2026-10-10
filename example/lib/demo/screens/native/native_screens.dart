import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';

import '../../../pages/examples_page.dart' show kAppTitle;
import '../../../theme/app_theme.dart';
import '../../demo_screen.dart';
import '../shared/native_request.dart';

// C1 / C3 rows (`lyt_native_in_app_events`).
const _fetchSuccess = 'fetchDemand success';
const _fetchFailed = 'fetchDemand failed';
const _getNativeSuccess = 'getNativeAd success';
const _getNativeFailed = 'getNativeAd failed';
const _clicked = 'onAdClicked';
const _impression = 'onAdImpression';
const _expired = 'onAdExpired';

/// C1 (In-App native, GAM Original Native In-App) and C3 (Native Ad Links).
///
/// In-App: the auction and the native response (`fetchDemand` →
/// `getNativeAd` in the original) then the ad rendered natively and
/// registered for tracking ([PrebidNativeAdView]). No Load button: it loads
/// on open.
///
/// GAM Original Native In-App: the original uses an Original API
/// `NativeAdUnit` + a GAM `AdLoader` with a custom format and
/// `AdViewUtils.findNative`. google_mobile_ads has no custom native formats,
/// so this runs the same flow through [PrebidGamNativeAd] (custom format
/// 11934135): its fetchDemand result fills the fetchDemand rows and the
/// rendered Prebid native the getNativeAd rows.
///
/// C3 renders the ad natively too (the plugin draws the native layout, so the
/// original's four link buttons can't be laid out separately); the four link
/// assets are listed under it.
class InAppNativeScreen extends DemoScreen {
  const InAppNativeScreen({super.key, required super.item});

  @override
  State<InAppNativeScreen> createState() => _InAppNativeScreenState();
}

class _InAppNativeScreenState extends DemoScreenState<InAppNativeScreen> {
  late final events = EventCounters([
    _fetchSuccess,
    _fetchFailed,
    _getNativeSuccess,
    _getNativeFailed,
    _clicked,
    _impression,
    _expired,
  ], tag: 'Native');

  PrebidNativeAd? _ad;
  PrebidNativeAdResponse? _response;

  bool get _original => item.integration == DemoIntegration.original;

  @override
  Future<void> startAd() async {
    if (_original) return; // The GAM native widget loads itself.
    final ad = _ad = PrebidNativeAd(
      configId: config.configId,
      assets: kStandardNativeAssets,
      eventTrackers: kStandardNativeTrackers,
      context: kNativeContext,
      contextSubType: kNativeContextSubType,
      placementType: kNativePlacement,
      listener: PrebidNativeAdListener(
        onAdLoaded: (response) {
          events.fire(_fetchSuccess);
          events.fire(_getNativeSuccess);
          if (mounted) setState(() => _response = response);
        },
        onAdFailed: (e) => events.fire(_fetchFailed, e),
        onAdClicked: () => events.fire(_clicked),
        onAdImpression: () => events.fire(_impression),
        onAdExpired: () => events.fire(_expired),
      ),
    );
    await ad.loadAd();
  }

  @override
  void destroyAd() => _ad?.destroy();

  Widget? _adView() {
    if (!started) return null;
    if (_original) {
      return PrebidGamNativeAd(
        configId: config.configId,
        gamAdUnitId: item.adUnitId ?? '',
        customFormatId: item.customFormatId ?? '11934135',
        assets: kStandardNativeAssets,
        eventTrackers: kStandardNativeTrackers,
        context: kNativeContext,
        contextSubType: kNativeContextSubType,
        placementType: kNativePlacement,
        listener: PrebidGamNativeAdListener(
          onFetchDemandSuccess: () => events.fire(_fetchSuccess),
          onFetchDemandFailed: (r) => events.fire(_fetchFailed, r),
          onNativeAdLoaded: () => events.fire(_getNativeSuccess),
          onPrimaryAdFailed: (e) => events.fire(_getNativeFailed, e),
          onAdClicked: () => events.fire(_clicked),
          onAdImpression: () => events.fire(_impression),
          onAdExpired: () => events.fire(_expired),
        ),
      );
    }
    final ad = _ad;
    if (ad == null || _response == null) return null;
    return PrebidNativeAdView(ad: ad);
  }

  @override
  Widget buildDemo(BuildContext context) {
    final response = _response;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ?_adView(),
        if (item.screen == ScreenType.c3 && response != null) ...[
          const SizedBox(height: 12),
          _LinkAssets(response: response),
        ],
        const SizedBox(height: 16),
        EventCounterList(counters: events),
      ],
    );
  }
}

/// C3's link assets: root link (CTA), deeplink-ok (description),
/// deeplink-fallback (sponsored by), link-url (rating).
class _LinkAssets extends StatelessWidget {
  const _LinkAssets({required this.response});
  final PrebidNativeAdResponse response;

  String? _data(NativeDataType type) {
    for (final d in response.dataAssets) {
      if (d.type == type.value) return d.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final rows = {
      'link-root': response.callToAction,
      'deeplink-ok': _data(NativeDataType.desc) ?? response.text,
      'deeplink-fallback':
          _data(NativeDataType.sponsored) ?? response.sponsoredBy,
      'link-url': _data(NativeDataType.rating),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in rows.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: OutlinedButton(
              onPressed: null,
              child: Text(
                '${e.key}: ${e.value ?? '—'}',
                style: AppFonts.monoStyle(fontSize: 12.5),
              ),
            ),
          ),
      ],
    );
  }
}

/// C2 — GAM native (`GamNativeFragment`): the auction, then GAM decides
/// between the Prebid native (rendered by Prebid), a GAM custom-format ad or
/// a GAM unified ad. No Load button: it loads on open.
class GamNativeScreen extends DemoScreen {
  const GamNativeScreen({super.key, required super.item});

  @override
  State<GamNativeScreen> createState() => _GamNativeScreenState();
}

class _GamNativeScreenState extends DemoScreenState<GamNativeScreen> {
  static const rows = [
    'fetchDemand success',
    'fetchDemand failed',
    'custom ad request successful',
    'unified ad request successful',
    'primary ad request failed',
    'onNativeAdLoaded called',
    'onPrimaryAdWin called (custom)',
    'onPrimaryAdWin called (unified)',
    'onAdClicked called',
    'onAdImpression',
  ];

  late final events = EventCounters(rows, tag: 'GAM native');

  @override
  Future<void> startAd() async {}

  @override
  Widget buildDemo(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (started) gamNative(item, config.configId, events),
        const SizedBox(height: 16),
        EventCounterList(counters: events),
      ],
    );
  }
}

/// A [PrebidGamNativeAd] for [item] reporting to the C2 rows of [events]
/// (`null` = no rows, for feeds).
Widget gamNative(DemoItem item, String configId, EventCounters? events) {
  void fire(String row, [String? detail]) => events?.fire(row, detail);
  return PrebidGamNativeAd(
    configId: configId,
    gamAdUnitId: item.adUnitId ?? '',
    customFormatId: item.customFormatId,
    assets: kStandardNativeAssets,
    eventTrackers: kStandardNativeTrackers,
    context: kNativeContext,
    contextSubType: kNativeContextSubType,
    placementType: kNativePlacement,
    listener: PrebidGamNativeAdListener(
      onFetchDemandSuccess: () => fire('fetchDemand success'),
      onFetchDemandFailed: (r) => fire('fetchDemand failed', r),
      onCustomAdLoaded: () => fire('custom ad request successful'),
      onUnifiedAdLoaded: () => fire('unified ad request successful'),
      onPrimaryAdFailed: (e) => fire('primary ad request failed', e),
      onNativeAdLoaded: () => fire('onNativeAdLoaded called'),
      onPrimaryAdWinCustom: () => fire('onPrimaryAdWin called (custom)'),
      onPrimaryAdWinUnified: () => fire('onPrimaryAdWin called (unified)'),
      onAdClicked: () => fire('onAdClicked called'),
      onAdImpression: () => fire('onAdImpression'),
    ),
  );
}

/// F — native feeds (In-App `PpmNativeFeedFragment`, GAM
/// `GamNativeFeedFragment`): an endless list of text rows with a native ad at
/// every position where `pos % 5 == 0 && pos != 0`, one ad per slot.
class NativeFeedScreen extends DemoScreen {
  const NativeFeedScreen({super.key, required super.item});

  @override
  State<NativeFeedScreen> createState() => _NativeFeedScreenState();
}

class _NativeFeedScreenState extends DemoScreenState<NativeFeedScreen> {
  @override
  Future<void> startAd() async {}

  @override
  Widget buildDemo(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, pos) {
        if (pos % 5 == 0 && pos != 0 && started) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: item.integration == DemoIntegration.gam
                ? gamNative(item, config.configId, null)
                : _FeedNativeAd(key: ValueKey(pos), configId: config.configId),
          );
        }
        return const ListTile(title: Text(kAppTitle));
      },
    );
  }
}

/// One In-App native ad of a feed slot.
class _FeedNativeAd extends StatefulWidget {
  const _FeedNativeAd({super.key, required this.configId});
  final String configId;

  @override
  State<_FeedNativeAd> createState() => _FeedNativeAdState();
}

class _FeedNativeAdState extends State<_FeedNativeAd> {
  late final PrebidNativeAd _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = PrebidNativeAd(
      configId: widget.configId,
      assets: kStandardNativeAssets,
      eventTrackers: kStandardNativeTrackers,
      context: kNativeContext,
      contextSubType: kNativeContextSubType,
      placementType: kNativePlacement,
      listener: PrebidNativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
      ),
    )..loadAd();
  }

  @override
  void dispose() {
    _ad.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _loaded ? PrebidNativeAdView(ad: _ad) : const SizedBox(height: 80);
}
