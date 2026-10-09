// Runs in its own isolate (one per test file), so the one-time release of a
// previous isolate's ads hasn't happened yet.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import 'mock_host_api.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the first ad releases the native ads of a previous isolate, once', () {
    final mobile = MockPrebidMobileHostApi();
    when(mobile.releaseAds()).thenAnswer((_) async {});
    PrebidMobile.api = mobile;

    PrebidInterstitialAd(configId: 'i');
    verify(mobile.releaseAds()).called(1);

    PrebidRewardedAd(configId: 'r');
    PrebidNativeAd(configId: 'n');
    PrebidMultiformatAd(configId: 'm', bannerSizes: const [Size(320, 50)]);
    PrebidInstreamVideoAd(configId: 'v', size: const Size(640, 480));
    verifyNever(mobile.releaseAds());
  });
}
