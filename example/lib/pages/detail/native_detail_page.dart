import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../../models/demo_ad_category.dart';
import '../../models/test_case.dart';
import '../../utils/logger.dart';
import '../../widgets/action_button.dart';
import '../../widgets/ad_unit_header.dart';
import '../../widgets/event_counter.dart';
import '../../widgets/native_ad_card.dart';

/// Native ad detail page — loads structured native assets and renders them
/// with a custom Flutter card, plus callback counters.
class NativeDetailPage extends StatefulWidget {
  final TestCase tc;
  const NativeDetailPage({super.key, required this.tc});

  @override
  State<NativeDetailPage> createState() => _NativeDetailPageState();
}

class _NativeDetailPageState extends State<NativeDetailPage> {
  final EventTracker _tracker = EventTracker();
  final _log = PrebidDemoLogger.instance;
  PrebidNativeAd? _ad;
  PrebidNativeAdResponse? _response;

  Future<void> _load() async {
    _ad?.destroy();
    _tracker.reset();
    setState(() => _response = null);

    _log.log('Native', 'Clearing stored response');
    await PrebidMobile.clearStoredAuctionResponse();
    _log.log('Native', 'Loading native ad: ${widget.tc.configId}');
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

  @override
  void dispose() {
    _ad?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tc.title)),
      body: ListenableBuilder(
        listenable: _tracker,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_response != null) NativeAdCard(response: _response!),
              AdUnitHeader(
                configId: widget.tc.configId,
                category: categoryOf(widget.tc),
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
                events: const [
                  'onAdLoaded',
                  'onAdFailed',
                  'onAdImpression',
                  'onAdClicked',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
