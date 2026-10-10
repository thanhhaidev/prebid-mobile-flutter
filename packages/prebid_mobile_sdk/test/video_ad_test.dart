import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

import 'mock_host_api.mocks.dart';

void main() {
  late MockInstreamVideoAdHostApi api;

  setUp(() {
    api = MockInstreamVideoAdHostApi();
    PrebidInstreamVideoAd.api = api;
  });

  test('fetchDemand sends the size and video parameters', () async {
    when(api.fetchDemand(any, any)).thenAnswer(
      (_) async => MultiformatBidResult(
        resultCode: 'prebidDemandFetchSuccess',
        targetingKeywords: {'hb_pb': '0.10'},
        exp: 300,
      ),
    );
    final result = await PrebidInstreamVideoAd(
      configId: 'video',
      size: const Size(640, 480),
      videoParameters: const VideoParameters(
        mimes: ['video/mp4'],
        plcmt: VideoPlcmt.accompanyingContent,
        startDelay: VideoStartDelay.genericMidRoll,
      ),
    ).fetchDemand();

    final config =
        verify(api.fetchDemand(any, captureAny)).captured.single
            as InstreamVideoAdRequestConfig;
    expect(config.configId, 'video');
    expect((config.width, config.height), (640, 480));
    expect(config.videoConfig?.mimes, ['video/mp4']);
    expect(config.videoConfig?.plcmt, 2);
    expect(config.videoConfig?.startDelay, -1);
    expect(result.isSuccess, isTrue);
    expect(result.targetingKeywords, {'hb_pb': '0.10'});
    expect(result.exp, 300);
  });

  test('without bids there are no keywords; destroy frees the ad', () async {
    when(api.fetchDemand(any, any)).thenAnswer(
      (_) async => MultiformatBidResult(resultCode: 'prebidDemandNoBids'),
    );
    final ad = PrebidInstreamVideoAd(configId: 'v', size: const Size(640, 360));
    final result = await ad.fetchDemand();
    final captured = verify(api.fetchDemand(captureAny, captureAny)).captured;
    expect((captured[1] as InstreamVideoAdRequestConfig).videoConfig, isNull);
    expect(result.isSuccess, isFalse);
    expect(result.targetingKeywords, isNull);

    await ad.destroy();
    verify(api.destroy(captured[0] as int)).called(1);
  });

  test('generateInstreamUriForGam flattens the sizes', () async {
    when(
      api.generateInstreamUriForGam(any, any, any),
    ).thenAnswer((_) async => 'https://pubads');
    final url = await PrebidInstreamVideoAd.generateInstreamUriForGam(
      gamAdUnitId: '/1/video',
      sizes: const [Size(640, 480), Size(400, 300)],
      targetingKeywords: const {'hb_pb': '1.00'},
    );
    expect(url, 'https://pubads');
    verify(
      api.generateInstreamUriForGam(
        '/1/video',
        [640, 480, 400, 300],
        {'hb_pb': '1.00'},
      ),
    ).called(1);
  });
}
