import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import '../../models/demo_ad_category.dart';
import '../../models/demo_integration.dart';
import '../../models/test_case.dart';
import '../../widgets/action_button.dart';
import '../../widgets/ad_unit_header.dart';
import '../../widgets/detail_scaffold.dart';
import '../../widgets/event_counter.dart';

/// Native ad detail page. In-App renders the loaded ad with
/// [PrebidNativeAdView]; GAM / AdMob / MAX render through the ad-server SDK's
/// native ad view. All are PlatformViews so impressions/clicks track correctly.
///
/// The callback list mirrors Prebid's reference test app: the GAM Original-API
/// native flow surfaces the full `fetchDemand` → custom/unified request →
/// `onPrimaryAdWin` / `onNativeAdLoaded` → impression/click sequence.
class NativeDetailPage extends StatefulWidget {
  final TestCase tc;
  const NativeDetailPage({super.key, required this.tc});

  @override
  State<NativeDetailPage> createState() => _NativeDetailPageState();
}

class _NativeDetailPageState extends State<NativeDetailPage> {
  final EventTracker _tracker = EventTracker('Native');

  // In-App asset rendering.
  PrebidNativeAd? _ad;
  PrebidNativeAdResponse? _response;

  // GAM / AdMob / MAX platform-view rendering.
  bool _showAd = false;
  int _adKey = 0;

  bool get _isInApp => widget.tc.integration == DemoIntegration.inApp;

  static const _defaultAssets = [
    NativeAsset.title(length: 90, required: true),
    NativeAsset.image(
      imageType: NativeImageType.main,
      widthMin: 200,
      heightMin: 50,
      required: true,
    ),
    NativeAsset.image(
      imageType: NativeImageType.icon,
      widthMin: 20,
      heightMin: 20,
      required: true,
    ),
    NativeAsset.data(dataType: NativeDataType.sponsored, required: true),
    NativeAsset.data(dataType: NativeDataType.desc, required: true),
    NativeAsset.data(dataType: NativeDataType.ctaText, required: true),
  ];

  void _track(String event) => _tracker.track(event);

  void _trackError(String event, String error) => _tracker.track(event, error);

  // ---- Mediated listeners -------------------------------------------------

  PrebidGamNativeAdListener _gamNativeListener() => PrebidGamNativeAdListener(
    onFetchDemandSuccess: () => _track('fetchDemand success'),
    onFetchDemandFailed: (reason) => _trackError('fetchDemand failed', reason),
    onCustomAdLoaded: () => _track('custom ad request successful'),
    onUnifiedAdLoaded: () => _track('unified ad request successful'),
    onPrimaryAdFailed: (e) => _trackError('primary ad request failed', e),
    onNativeAdLoaded: () => _track('onNativeAdLoaded called'),
    onPrimaryAdWinCustom: () => _track('onPrimaryAdWin called (custom)'),
    onPrimaryAdWinUnified: () => _track('onPrimaryAdWin called (unified)'),
    onAdImpression: () => _track('onAdImpression'),
    onAdClicked: () => _track('onAdClicked called'),
    onAdExpired: () => _track('onAdExpired'),
  );

  PrebidAdMobNativeAdListener _admobNativeListener() =>
      PrebidAdMobNativeAdListener(
        onAdLoaded: () => _track('onAdLoaded'),
        onAdImpression: () => _track('onAdImpression'),
        onAdClicked: () => _track('onAdClicked'),
        onAdOpened: () => _track('onAdOpened'),
        onAdFailed: (e) => _trackError('onAdFailed', e),
      );

  PrebidMaxNativeAdListener _maxNativeListener() => PrebidMaxNativeAdListener(
    onAdLoaded: () => _track('onAdLoaded'),
    onAdFailed: (e) => _trackError('onAdFailed', e),
    onAdImpression: () => _track('onAdImpression'),
    onAdClicked: () => _track('onAdClicked'),
  );

  /// The callback rows shown for the current integration, matching the
  /// reference test app.
  List<String> _events() {
    switch (widget.tc.integration) {
      case DemoIntegration.gam:
        return const [
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
          'onAdExpired',
        ];
      case DemoIntegration.admob:
        return const [
          'onAdLoaded',
          'onAdImpression',
          'onAdClicked',
          'onAdOpened',
          'onAdFailed',
        ];
      case DemoIntegration.max:
        return const [
          'onAdLoaded',
          'onAdImpression',
          'onAdClicked',
          'onAdFailed',
        ];
      case DemoIntegration.inApp:
      case DemoIntegration.original:
        return const [
          'onAdLoaded',
          'onAdFailed',
          'onAdImpression',
          'onAdClicked',
          'onAdExpired',
        ];
    }
  }

  Future<void> _load() async {
    _tracker.reset();
    await PrebidMobile.clearStoredAuctionResponse();
    _tracker.track(
      'load',
      '${widget.tc.integration.label} ${widget.tc.configId}',
    );

    if (!_isInApp) {
      // GAM / AdMob / MAX: the platform view loads itself on (re)creation.
      setState(() {
        _showAd = true;
        _adKey++;
      });
      return;
    }

    _ad?.destroy();
    setState(() => _response = null);
    await PrebidMobile.setShouldAssignNativeAssetId(
      widget.tc.assignNativeAssetIds,
    );
    _ad = PrebidNativeAd(
      configId: widget.tc.configId,
      assets: widget.tc.nativeAssets ?? _defaultAssets,
      eventTrackers: const [
        NativeEventTracker(
          eventType: NativeEventType.impression,
          methods: [
            NativeEventTrackingMethod.image,
            NativeEventTrackingMethod.js,
          ],
        ),
      ],
      listener: PrebidNativeAdListener(
        onAdLoaded: (response) {
          _tracker.track(
            'onAdLoaded',
            'title="${response.title}" privacy=${response.privacyUrl} '
                'assets: ${response.titles.length} title, '
                '${response.images.length} image, '
                '${response.dataAssets.length} data',
          );
          setState(() => _response = response);
        },
        onAdFailed: (e) => _trackError('onAdFailed', e),
        onAdImpression: () => _track('onAdImpression'),
        onAdClicked: () => _track('onAdClicked'),
        onAdExpired: () => _track('onAdExpired'),
      ),
    );
    _ad!.loadAd();
  }

  Widget _mediatedNativeWidget() {
    final key = ValueKey(_adKey);
    final adUnitId = widget.tc.adUnitId ?? '';
    return switch (widget.tc.integration) {
      DemoIntegration.gam => PrebidGamNativeAd(
        key: key,
        configId: widget.tc.configId,
        gamAdUnitId: adUnitId,
        customFormatId: widget.tc.customFormatId,
        listener: _gamNativeListener(),
      ),
      DemoIntegration.admob => PrebidAdMobNativeAd(
        key: key,
        configId: widget.tc.configId,
        adMobAdUnitId: adUnitId,
        listener: _admobNativeListener(),
      ),
      DemoIntegration.max => PrebidMaxNativeAd(
        key: key,
        configId: widget.tc.configId,
        maxAdUnitId: adUnitId,
        listener: _maxNativeListener(),
      ),
      DemoIntegration.inApp ||
      DemoIntegration.original => const SizedBox.shrink(),
    };
  }

  @override
  void dispose() {
    _ad?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget? ad;
    if (_isInApp && _response != null && _ad != null) {
      // Rendered natively so Prebid tracks impressions/clicks.
      ad = PrebidNativeAdView(ad: _ad!);
    } else if (!_isInApp && _showAd) {
      ad = _mediatedNativeWidget();
    } else {
      ad = null;
    }
    return AdDetailScaffold(
      title: widget.tc.title,
      tracker: _tracker,
      events: _events(),
      stage: AdStage(child: ad),
      header: AdUnitHeader(
        configId: widget.tc.configId,
        category: categoryOf(widget.tc),
        integration: widget.tc.integration,
        adUnitId: widget.tc.adUnitId,
      ),
      actions: [
        ActionButton(
          label: 'Load',
          icon: Icons.download_rounded,
          onPressed: _load,
        ),
      ],
    );
  }
}
