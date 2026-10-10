import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import 'channel_harness.dart';

// Its own file (isolate): `releaseAll` goes out once per channel per isolate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'each channel releases the native ads once, before its first call',
    () async {
      final i = ChannelHarness('prebid_mobile_sdk_max/interstitial');
      final r = ChannelHarness('prebid_mobile_sdk_max/rewarded');

      final interstitial = PrebidMaxInterstitialAd(
        configId: 'c',
        maxAdUnitId: 'u',
      );
      await interstitial.loadAd();
      await interstitial.show();
      await PrebidMaxInterstitialAd(configId: 'c', maxAdUnitId: 'u').loadAd();
      expect(i.releaseAllCalls, 1);
      expect(i.calls.map((c) => c.method), ['load', 'show', 'load']);
      expect(r.releaseAllCalls, 0);

      final rewarded = PrebidMaxRewardedAd(configId: 'c', maxAdUnitId: 'u');
      await rewarded.loadAd();
      await rewarded.destroy();
      expect(r.releaseAllCalls, 1);
      expect(r.calls.map((c) => c.method), ['load', 'destroy']);
    },
  );
}
