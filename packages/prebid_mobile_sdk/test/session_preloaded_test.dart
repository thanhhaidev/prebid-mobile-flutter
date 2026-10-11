// Runs in its own isolate (one per test file), so the one-time release of a
// previous isolate's ads hasn't happened yet.
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import 'mock_host_api.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a preloaded banner first releases a previous isolate\'s ads', () async {
    final mobile = MockPrebidMobileHostApi();
    when(mobile.releaseAds()).thenAnswer((_) async {});
    PrebidMobile.api = mobile;
    final banners = MockBannerAdHostApi();
    PrebidPreloadedBannerAd.api = banners;

    await PrebidPreloadedBannerAd(configId: 'b', width: 320, height: 50).load();
    verifyInOrder([mobile.releaseAds(), banners.create(any, any)]);

    await PrebidPreloadedBannerAd(configId: 'c', width: 320, height: 50).load();
    verifyNoMoreInteractions(mobile);
  });
}
