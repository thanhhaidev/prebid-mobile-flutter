import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../../demo_screen.dart';
import '../shared/native_request.dart';

/// D — "Multiformat (Banner + Video + …) (GAM Original)"
/// (`GamOriginalMultiformatBannerVideoNative(Styles)Fragment`).
///
/// Toggles **Banner** / **Video** / **Native** (all on; **Load** is disabled
/// while fewer than two are on) · **Load** · ad container · 4 rows. No
/// auto-load. Load runs a `PrebidAdUnit` request (banner 320x50 + 300x250,
/// mp4 video, the standard native assets with an image tracker) with a config
/// id picked at random from the enabled formats, then the GAM request with
/// the winning keywords.
///
/// The original GAM side is a multi-format `AdLoader` (banner + MREC + native
/// + custom format 12304464, then `findNative`) or an `AdManagerAdView` mixing
/// FLUID with fixed sizes. google_mobile_ads has neither, so this loads an
/// Ad Manager banner (320x50, 300x250) with the keywords: banner and video
/// wins render; a native win renders as GAM's banner creative.
class MultiformatScreen extends DemoScreen {
  const MultiformatScreen({super.key, required super.item});

  @override
  State<MultiformatScreen> createState() => _MultiformatScreenState();
}

class _MultiformatScreenState extends DemoScreenState<MultiformatScreen> {
  static const loaded = 'onAdLoaded called';
  static const impression = 'onAdImpression called';
  static const clicked = 'onAdClicked called';
  static const failed = 'onAdFailed called';

  late final events = EventCounters([
    loaded,
    impression,
    clicked,
    failed,
  ], tag: 'Multiformat');

  bool _banner = true;
  bool _video = true;
  bool _native = true;
  bool _loading = false;
  PrebidMultiformatAd? _unit;
  gma.AdManagerBannerAd? _ad;
  Size? _size;

  int get _enabledCount => [_banner, _video, _native].where((b) => b).length;

  @override
  Future<void> startAd() async {} // No auto-load.

  List<String> get _enabledConfigs {
    final ids = item.randomConfigIds ?? const <String>[];
    return [
      if (_banner && ids.isNotEmpty) ids[0],
      if (_video && ids.length > 1) ids[1],
      if (_native && ids.length > 2) ids[2],
    ];
  }

  Future<void> _load() async {
    events.reset(only: events.labels);
    unawaited(_ad?.dispose());
    setState(() {
      _ad = null;
      _size = null;
      _loading = true;
    });
    await _unit?.destroy();
    final configs = _enabledConfigs;
    final unit = _unit = PrebidMultiformatAd(
      configId: configs[Random().nextInt(configs.length)],
      bannerSizes: _banner ? const [Size(320, 50), Size(300, 250)] : null,
      videoParameters: _video ? kMp4Video : null,
      nativeParameters: _native ? kOriginalNativeParameters : null,
    );
    final response = await unit.fetchDemand();
    if (!mounted) return;
    final ad = gma.AdManagerBannerAd(
      adUnitId: item.adUnitId ?? '',
      sizes: const [gma.AdSize.banner, gma.AdSize.mediumRectangle],
      request: gma.AdManagerAdRequest(
        customTargeting: response.targetingKeywords ?? {},
      ),
      listener: gma.AdManagerBannerAdListener(
        onAdLoaded: (ad) async {
          final size = await (ad as gma.AdManagerBannerAd).getPlatformAdSize();
          events.fire(loaded);
          if (!mounted) return;
          setState(() {
            _loading = false;
            if (size != null) {
              _size = Size(size.width.toDouble(), size.height.toDouble());
            }
          });
        },
        onAdFailedToLoad: (ad, e) {
          ad.dispose();
          events.fire(failed, e.message);
          if (mounted) setState(() => _loading = false);
        },
        onAdImpression: (_) => events.fire(impression),
        onAdClicked: (_) => events.fire(clicked),
      ),
    );
    setState(() => _ad = ad);
    await ad.load();
  }

  @override
  void destroyAd() {
    _unit?.destroy();
    _ad?.dispose();
  }

  Widget _toggle(String name, bool value, ValueChanged<bool> onChanged) =>
      FilterChip(
        label: Text('$name ${value ? 'On' : 'Off'}'),
        selected: value,
        onSelected: (v) => setState(() => onChanged(v)),
      );

  @override
  Widget buildDemo(BuildContext context) {
    final ad = _ad;
    final size = _size;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _toggle('Banner', _banner, (v) => _banner = v),
            _toggle('Video', _video, (v) => _video = v),
            _toggle('Native', _native, (v) => _native = v),
          ],
        ),
        const SizedBox(height: 12),
        DemoButton(
          'Load',
          onPressed: !_loading && _enabledCount >= 2 ? _load : null,
        ),
        const SizedBox(height: 16),
        if (ad != null && size != null)
          Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: gma.AdWidget(ad: ad),
            ),
          ),
        const SizedBox(height: 16),
        EventCounterList(counters: events),
      ],
    );
  }
}
