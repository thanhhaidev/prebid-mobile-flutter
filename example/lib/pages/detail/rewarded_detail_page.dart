import 'package:flutter/material.dart';
import 'package:prebid_mobile_flutter/prebid_mobile_flutter.dart';

import '../../models/demo_ad_format.dart';
import '../../models/test_case.dart';
import '../../utils/logger.dart';
import '../../widgets/action_button.dart';
import '../../widgets/config_info_panel.dart';
import '../../widgets/event_counter.dart';
import '../../widgets/expandable_error_panel.dart';
import '../../widgets/log_viewer_panel.dart';

/// Rewarded ad detail page.
///
/// Mirrors `InAppDisplayRewardedViewController` / `InAppVideoRewardedViewController`.
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
  bool _canShow = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _rewardInfo;
  int? _loadTimeMs;
  final Stopwatch _stopwatch = Stopwatch();

  bool get _isVideo => widget.tc.format == DemoAdFormat.videoRewarded;

  Future<void> _load() async {
    _ad?.destroy();
    _tracker.reset();
    setState(() {
      _canShow = false;
      _isLoading = true;
      _errorMessage = null;
      _rewardInfo = null;
      _loadTimeMs = null;
    });
    _stopwatch.reset();
    _stopwatch.start();

    _log.log('Rewarded', 'Clearing stored response');
    await PrebidMobile.clearStoredAuctionResponse();
    if (widget.tc.storedResponse != null) {
      _log.log('Rewarded', 'Setting stored response: ${widget.tc.storedResponse}');
      await PrebidMobile.setStoredAuctionResponse(widget.tc.storedResponse!);
    }

    _log.log('Rewarded', 'Loading ${_isVideo ? "video" : "display"} rewarded: ${widget.tc.configId}');
    _ad = PrebidRewardedAd(
      configId: widget.tc.configId,
      listener: PrebidRewardedAdListener(
        onAdLoaded: () {
          _stopwatch.stop();
          _tracker.track('onAdLoaded');
          _log.log('Rewarded', 'Ad loaded in ${_stopwatch.elapsedMilliseconds}ms');
          setState(() {
            _canShow = true;
            _isLoading = false;
            _loadTimeMs = _stopwatch.elapsedMilliseconds;
          });
        },
        onAdFailed: (e) {
          _stopwatch.stop();
          _tracker.track('onAdFailed', e);
          _log.log('Rewarded', 'Ad failed in ${_stopwatch.elapsedMilliseconds}ms: $e', level: LogLevel.error);
          setState(() {
            _isLoading = false;
            _errorMessage = e;
            _loadTimeMs = _stopwatch.elapsedMilliseconds;
          });
        },
        onAdDisplayed: () {
          _tracker.track('onAdDisplayed');
          _log.log('Rewarded', 'Ad displayed');
        },
        onAdDismissed: () {
          _tracker.track('onAdDismissed');
          _log.log('Rewarded', 'Ad dismissed');
          setState(() => _canShow = false);
        },
        onAdClicked: () {
          _tracker.track('onAdClicked');
          _log.log('Rewarded', 'Ad clicked');
        },
        onUserEarnedReward: (r) {
          _tracker.track('onUserEarnedReward');
          final info = 'type=${r.type}, count=${r.count}';
          _log.log('Rewarded', 'User earned reward: $info');
          setState(() => _rewardInfo = info);
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
              // Format badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isVideo ? Colors.orange.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isVideo ? '🎯 Video Rewarded' : '🏆 Display Rewarded',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isVideo ? Colors.orange.shade700 : Colors.amber.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Reward info badge
              if (_rewardInfo != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Reward: $_rewardInfo',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900)),
                      ),
                    ],
                  ),
                ),

              // Loading indicator
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Loading ad...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),

              // Error display
              if (_errorMessage != null)
                ExpandableErrorPanel(error: _errorMessage!),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ActionButton(label: 'Load', onPressed: _load),
                  const SizedBox(width: 24),
                  ActionButton(
                      label: 'Show',
                      onPressed: _canShow ? () => _ad?.show() : null),
                ],
              ),
              const Divider(),
              EventCounterList(
                tracker: _tracker,
                events: const [
                  'onAdLoaded', 'onAdFailed', 'onAdDisplayed',
                  'onAdClicked', 'onAdDismissed', 'onUserEarnedReward',
                ],
              ),
              const SizedBox(height: 12),
              ConfigInfoPanel(tc: widget.tc, loadTimeMs: _loadTimeMs),
              const SizedBox(height: 12),
              const LogViewerPanel(),
            ],
          ),
        ),
      ),
    );
  }
}
