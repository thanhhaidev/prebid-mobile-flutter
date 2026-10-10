import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../../demo_screen.dart';
import '../shared/native_request.dart';
import 'banner_screen.dart' show gamSizesFor;

/// A GAM Original (Original API) banner: the Prebid auction, then a Google
/// Ad Manager banner requested with the winning targeting keywords — the
/// original `GamOriginalBannerFragment` family:
///
/// - display banners (`BannerAdUnit`, + 728x90 for multisize);
/// - outstream video (`BannerAdUnit` with {VIDEO});
/// - banner + video multiformat (random config, mp4);
/// - native styles (`NativeAdUnit`, fluid GAM banner);
/// - memory leak: auction only, no GAM view.
///
/// Auto-refresh re-runs the auction every [refreshSeconds] and reloads the
/// GAM banner with the new keywords (the Android SDK refreshes the GAM view
/// itself). The banner takes the size GAM reports after loading, standing in
/// for `AdViewUtils.findPrebidCreativeSize`.
class OriginalBannerAd extends StatefulWidget {
  const OriginalBannerAd({
    super.key,
    required this.item,
    required this.config,
    this.refreshSeconds,
    this.onLoaded,
    this.onFailed,
    this.onClicked,
  });
  final DemoItem item;
  final AdConfiguration config;
  final int? refreshSeconds;
  final VoidCallback? onLoaded;
  final void Function(String error)? onFailed;
  final VoidCallback? onClicked;

  @override
  State<OriginalBannerAd> createState() => OriginalBannerAdState();
}

class OriginalBannerAdState extends State<OriginalBannerAd> {
  PrebidMultiformatAd? _unit;
  gma.AdManagerBannerAd? _banner;
  gma.FluidAdManagerBannerAd? _fluid;
  Size? _size;

  DemoItem get _item => widget.item;
  bool get _native => _item.category == DemoCategory.native;
  bool get _memoryLeak => _item.has(DemoFlag.memoryLeak);

  @override
  void initState() {
    super.initState();
    load();
  }

  PrebidMultiformatAd _createUnit() {
    final formats = _item.adFormats ?? const {PrebidAdFormat.banner};
    final c = widget.config;
    return PrebidMultiformatAd(
      configId: c.configId,
      bannerSizes: _native || !formats.contains(PrebidAdFormat.banner)
          ? null
          : [
              Size(c.width.toDouble(), c.height.toDouble()),
              ...?_item.additionalSizes,
            ],
      // The video size comes from the stored request on Prebid Server.
      videoParameters: formats.contains(PrebidAdFormat.video)
          ? (_item.videoParameters ?? kMp4Video)
          : null,
      onDemandRefreshed: (r) => _loadGam(r.targetingKeywords),
      nativeParameters: _native ? kOriginalNativeParameters : null,
    );
  }

  /// Runs the auction and loads the GAM banner with its keywords.
  Future<void> load() async {
    await _unit?.destroy();
    final unit = _unit = _createUnit();
    final response = await unit.fetchDemand();
    if (!mounted || _memoryLeak) return;
    final refresh = widget.refreshSeconds;
    if (refresh != null && refresh > 0) {
      await unit.setAutoRefreshInterval(refresh);
    }
    _loadGam(response.targetingKeywords);
  }

  Future<void> stopRefresh() async => _unit?.stopAutoRefresh();

  void _loadGam(Map<String, String>? keywords) {
    if (!mounted) return;
    final request = gma.AdManagerAdRequest(customTargeting: keywords ?? {});
    final listener = gma.AdManagerBannerAdListener(
      onAdLoaded: (ad) async {
        final size = await (ad as gma.AdManagerBannerAd).getPlatformAdSize();
        if (!mounted) return;
        setState(() {
          if (size != null) {
            _size = Size(size.width.toDouble(), size.height.toDouble());
          }
        });
        widget.onLoaded?.call();
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        widget.onFailed?.call(error.message);
      },
      onAdClicked: (_) => widget.onClicked?.call(),
    );

    _banner?.dispose();
    _fluid?.dispose();
    _banner = null;
    _fluid = null;
    final adUnitId = _item.adUnitId ?? '';
    if (_native) {
      _fluid = gma.FluidAdManagerBannerAd(
        adUnitId: adUnitId,
        request: request,
        listener: listener,
      )..load();
    } else {
      _banner = gma.AdManagerBannerAd(
        adUnitId: adUnitId,
        sizes: gamSizesFor(_item, widget.config),
        request: request,
        listener: listener,
      )..load();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _unit?.destroy();
    _banner?.dispose();
    _fluid?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fluid = _fluid;
    if (fluid != null) {
      return SizedBox(
        width: MediaQuery.sizeOf(context).width - 32,
        child: gma.FluidAdWidget(ad: fluid),
      );
    }
    final banner = _banner;
    final size =
        _size ??
        Size(widget.config.width.toDouble(), widget.config.height.toDouble());
    if (banner == null || _memoryLeak) return const SizedBox.shrink();
    return SizedBox(
      width: size.width,
      height: size.height,
      child: gma.AdWidget(ad: banner),
    );
  }
}
