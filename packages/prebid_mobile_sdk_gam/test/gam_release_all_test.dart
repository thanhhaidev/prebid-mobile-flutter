import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';

import 'channel_harness.dart';

// Its own file: `releaseAll` goes out once per channel per isolate, before
// the channel's first call, and each test file runs in a fresh isolate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each channel releases the native ads once, first', () async {
    final interstitial = ChannelHarness('prebid_mobile_sdk_gam/interstitial');
    final rewarded = ChannelHarness('prebid_mobile_sdk_gam/rewarded');

    final i = PrebidGamInterstitialAd(configId: 'c', gamAdUnitId: 'u');
    await i.loadAd();
    await i.show();
    expect(interstitial.releaseAllCalls, 1);
    expect(interstitial.calls.map((c) => c.method), ['load', 'show']);
    expect(rewarded.releaseAllCalls, 0);

    final r = PrebidGamRewardedAd(configId: 'c', gamAdUnitId: 'u');
    await r.loadAd();
    await r.destroy();
    await PrebidGamRewardedAd(configId: 'c', gamAdUnitId: 'u').loadAd();
    expect(rewarded.releaseAllCalls, 1);
    expect(rewarded.calls.map((c) => c.method), ['load', 'destroy', 'load']);
  });
}
