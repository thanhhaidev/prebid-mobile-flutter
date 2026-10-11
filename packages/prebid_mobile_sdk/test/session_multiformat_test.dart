// Runs in its own isolate (one per test file), so the one-time release of a
// previous isolate's ads hasn't happened yet.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

import 'mock_host_api.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an Original API unit without a refresh callback first releases a '
      'previous isolate\'s ads', () async {
    final mobile = MockPrebidMobileHostApi();
    when(mobile.releaseAds()).thenAnswer((_) async {});
    PrebidMobile.api = mobile;
    final units = MockMultiformatAdHostApi();
    when(units.fetchDemand(any, any)).thenAnswer(
      (_) async => MultiformatBidResult(resultCode: 'prebidDemandNoBids'),
    );
    PrebidMultiformatAd.api = units;

    await PrebidBannerAdUnit(
      configId: 'b',
      sizes: const [Size(320, 50)],
    ).fetchDemand();
    verifyInOrder([mobile.releaseAds(), units.fetchDemand(any, any)]);
  });
}
