import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import '../../models/demo_ad_category.dart';
import '../../models/demo_integration.dart';
import '../../models/test_case.dart';
import '../../utils/logger.dart';
import '../../widgets/action_button.dart';
import '../../widgets/ad_unit_header.dart';
import '../../widgets/event_counter.dart';
import '../../widgets/native_ad_card.dart';

/// Native ad detail page. In-App renders structured native assets with a custom
/// Flutter card; AdMob / MAX render through the mediation SDK's native ad view
/// (a PlatformView) so impressions/clicks track correctly.
class NativeDetailPage extends StatefulWidget {
  final TestCase tc;
  const NativeDetailPage({super.key, required this.tc});

  @override
  State<NativeDetailPage> createState() => _NativeDetailPageState();
}

class _NativeDetailPageState extends State<NativeDetailPage> {
  final EventTracker _tracker = EventTracker();
  final _log = PrebidDemoLogger.instance;

  // In-App asset rendering.
  PrebidNativeAd? _ad;
  PrebidNativeAdResponse? _response;

  // AdMob / MAX platform-view rendering.
  bool _showAd = false;
  int _adKey = 0;

  bool get _isInApp => widget.tc.integration == DemoIntegration.inApp;

  PrebidBannerAdListener _mediatedListener() => PrebidBannerAdListener(
    onAdLoaded: () {
      _tracker.track('onAdLoaded');
      _log.log('Native', 'Ad loaded');
    },
    onAdFailed: (e) {
      _tracker.track('onAdFailed', e);
      _log.log('Native', 'Ad failed: $e', level: LogLevel.error);
    },
    onAdClicked: () {
      _tracker.track('onAdClicked');
      _log.log('Native', 'Ad clicked');
    },
  );

  Future<void> _load() async {
    _tracker.reset();
    await PrebidMobile.clearStoredAuctionResponse();
    _log.log('Native', 'Loading ${widget.tc.integration.label}: '
        '${widget.tc.configId}');

    if (!_isInApp) {
      // AdMob / MAX: the platform view loads itself on (re)creation.
      setState(() {
        _showAd = true;
        _adKey++;
      });
      return;
    }

    _ad?.destroy();
    setState(() => _response = null);
    _ad = PrebidNativeAd(
      configId: widget.tc.configId,
      assets: const [
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
      ],
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
          _tracker.track('onAdLoaded');
          _log.log('Native', 'Ad loaded: title="${response.title}"');
          setState(() => _response = response);
        },
        onAdFailed: (e) {
          _tracker.track('onAdFailed', e);
          _log.log('Native', 'Ad failed: $e', level: LogLevel.error);
        },
        onAdImpression: () {
          _tracker.track('onAdImpression');
          _log.log('Native', 'Ad impression tracked');
        },
        onAdClicked: () {
          _tracker.track('onAdClicked');
          _log.log('Native', 'Ad clicked');
        },
      ),
    );
    _ad!.loadAd();
  }

  Widget _mediatedNativeWidget() {
    final key = ValueKey(_adKey);
    final adUnitId = widget.tc.adUnitId ?? '';
    if (widget.tc.integration == DemoIntegration.admob) {
      return PrebidAdMobNativeAd(
        key: key,
        configId: widget.tc.configId,
        adMobAdUnitId: adUnitId,
        listener: _mediatedListener(),
      );
    }
    return PrebidMaxNativeAd(
      key: key,
      configId: widget.tc.configId,
      maxAdUnitId: adUnitId,
      listener: _mediatedListener(),
    );
  }

  @override
  void dispose() {
    _ad?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.tc.title)),
      body: ListenableBuilder(
        listenable: _tracker,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_isInApp && _response != null)
                NativeAdCard(response: _response!)
              else if (!_isInApp && _showAd)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _mediatedNativeWidget(),
                ),
              const SizedBox(height: 16),
              AdUnitHeader(
                configId: widget.tc.configId,
                category: categoryOf(widget.tc),
                integration: widget.tc.integration,
                adUnitId: widget.tc.adUnitId,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ActionButton(
                  label: 'Load',
                  icon: Icons.download_rounded,
                  onPressed: _load,
                ),
              ),
              const SizedBox(height: 16),
              EventCounterList(
                tracker: _tracker,
                events: _isInApp
                    ? const [
                        'onAdLoaded',
                        'onAdFailed',
                        'onAdImpression',
                        'onAdClicked',
                      ]
                    : const ['onAdLoaded', 'onAdFailed', 'onAdClicked'],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
