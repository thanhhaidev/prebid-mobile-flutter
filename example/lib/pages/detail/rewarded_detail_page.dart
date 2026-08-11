import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import '../../models/demo_ad_category.dart';
import '../../models/test_case.dart';
import '../../utils/logger.dart';
import '../../widgets/action_button.dart';
import '../../widgets/ad_unit_header.dart';
import '../../widgets/configure_ad_dialog.dart';
import '../../widgets/event_counter.dart';

/// Rewarded ad detail page — Load then Show, granting a reward on completion.
class RewardedDetailPage extends StatefulWidget {
  final TestCase tc;
  const RewardedDetailPage({super.key, required this.tc});

  @override
  State<RewardedDetailPage> createState() => _RewardedDetailPageState();
}

class _RewardedDetailPageState extends State<RewardedDetailPage> {
  final EventTracker _tracker = EventTracker();
  final _log = PrebidDemoLogger.instance;
  PrebidRewardedAd? _ad;
  late String _configId = widget.tc.configId;
  bool _canShow = false;

  Future<void> _load() async {
    _ad?.destroy();
    _tracker.reset();
    setState(() => _canShow = false);
    _log.log('Rewarded', 'Clearing stored response');
    await PrebidMobile.clearStoredAuctionResponse();
    _log.log('Rewarded', 'Loading: $_configId');
    _ad = PrebidRewardedAd(
      configId: _configId,
      listener: PrebidRewardedAdListener(
        onAdLoaded: () {
          _tracker.track('onAdLoaded');
          _log.log('Rewarded', 'Ad loaded');
          setState(() => _canShow = true);
        },
        onAdFailed: (e) {
          _tracker.track('onAdFailed', e);
          _log.log('Rewarded', 'Ad failed: $e', level: LogLevel.error);
        },
        onAdDisplayed: () {
          _tracker.track('onAdDisplayed');
          _log.log('Rewarded', 'Ad displayed');
        },
        onAdClicked: () {
          _tracker.track('onAdClicked');
          _log.log('Rewarded', 'Ad clicked');
        },
        onAdClosed: () {
          _tracker.track('onAdClosed');
          _log.log('Rewarded', 'Ad closed');
          setState(() => _canShow = false);
        },
        onUserEarnedReward: (r) {
          _tracker.track('onUserEarnedReward');
          _log.log('Rewarded', 'Earned: ${r.count}x ${r.type}');
        },
      ),
    );
    _ad!.loadAd();
  }

  Future<void> _configure() async {
    final cfg = await ConfigureAdDialog.show(
      context,
      initial: AdConfig(
        configId: _configId,
        width: 0,
        height: 0,
        refreshDelay: 0,
      ),
      showSize: false,
      showRefresh: false,
    );
    if (cfg == null) return;
    setState(() => _configId = cfg.configId);
    await _load();
  }

  @override
  void dispose() {
    _ad?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tc.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Configure the Ad',
            onPressed: _configure,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _tracker,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AdUnitHeader(
                configId: _configId,
                category: categoryOf(widget.tc),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      label: 'Load',
                      icon: Icons.download_rounded,
                      onPressed: _load,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton(
                      label: 'Show',
                      primary: false,
                      icon: Icons.open_in_full_rounded,
                      onPressed: _canShow ? () => _ad?.show() : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              EventCounterList(
                tracker: _tracker,
                events: const [
                  'onAdLoaded',
                  'onAdDisplayed',
                  'onAdFailed',
                  'onAdClicked',
                  'onAdClosed',
                  'onUserEarnedReward',
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
