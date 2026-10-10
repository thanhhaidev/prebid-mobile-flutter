import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

import 'mock_host_api.mocks.dart';

void main() {
  late MockMultiformatAdHostApi api;

  setUp(() {
    api = MockMultiformatAdHostApi();
    PrebidMultiformatAd.api = api;
    when(api.fetchDemand(any, any)).thenAnswer(
      (_) async => MultiformatBidResult(
        resultCode: 'prebidDemandFetchSuccess',
        targetingKeywords: {'hb_pb': '1.00'},
      ),
    );
  });

  group('PrebidRewardedAdUnit', () {
    test('requests a rewarded video interstitial', () async {
      final response = await PrebidRewardedAdUnit(
        configId: 'r',
        videoParameters: const VideoParameters(
          mimes: ['video/mp4'],
          maxDuration: 30,
        ),
        trackImpression: true,
        gpid: '/1/rewarded',
        pbAdSlot: '/slot',
        impOrtbConfig: '{"ext":{}}',
        globalOrtbConfig: '{"app":{}}',
      ).fetchDemand();

      final config =
          verify(api.fetchDemand(any, captureAny)).captured.single
              as MultiformatAdRequestConfig;
      expect(config.configId, 'r');
      expect(config.isInterstitial, isTrue);
      expect(config.isRewarded, isTrue);
      expect(config.bannerSizes, isNull);
      expect(config.nativeConfig, isNull);
      expect(config.videoConfig?.mimes, ['video/mp4']);
      expect(config.videoConfig?.maxDuration, 30);
      expect(config.trackInterstitialImpression, isTrue);
      expect(config.gpid, '/1/rewarded');
      expect(config.pbAdSlot, '/slot');
      expect(config.impOrtbConfig, '{"ext":{}}');
      expect(config.globalOrtbConfig, '{"app":{}}');
      expect(response.isSuccess, isTrue);
      expect(response.targetingKeywords, {'hb_pb': '1.00'});
    });
  });
}
