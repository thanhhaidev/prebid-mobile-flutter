import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';

import 'channel_harness.dart';

// Its own file: `releaseAll` goes out once per isolate and channel, so no
// other test may touch these channels first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'each channel releases the native ads once, before its first call',
    () async {
      final i = ChannelHarness('prebid_mobile_sdk_admob/interstitial');
      final r = ChannelHarness('prebid_mobile_sdk_admob/rewarded');

      final interstitial = PrebidAdMobInterstitialAd(
        configId: 'c',
        adMobAdUnitId: 'u',
      );
      await interstitial.loadAd();
      expect(i.releaseAllCalls, 1);
      expect(r.releaseAllCalls, 0);
      await interstitial.show();
      await interstitial.destroy();
      await PrebidAdMobInterstitialAd(
        configId: 'c',
        adMobAdUnitId: 'u',
      ).loadAd();
      expect(i.releaseAllCalls, 1);
      expect(i.calls.map((c) => c.method), ['load', 'show', 'destroy', 'load']);

      await PrebidAdMobRewardedAd(configId: 'c', adMobAdUnitId: 'u').loadAd();
      expect(r.releaseAllCalls, 1);
      expect(r.calls.single.method, 'load');
    },
  );
}
