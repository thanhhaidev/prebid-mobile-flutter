import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/ad_event_router.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

import 'mock_host_api.mocks.dart';

const _video = VideoParameters(
  mimes: ['video/mp4'],
  protocols: [VideoProtocol.vast4_0],
  placement: VideoPlacement.inArticle,
  plcmt: VideoPlcmt.accompanyingContent,
  startDelay: VideoStartDelay.genericMidRoll,
  linearity: VideoLinearity.linear,
  skippable: true,
  battr: [VideoCreativeAttribute.annoying, VideoCreativeAttribute.surveys],
  minBitrate: 300,
  maxBitrate: 1500,
  maxDuration: 30,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoParameters', () {
    test('toConfig carries the OpenRTB 2.6 fields', () {
      final c = _video.toConfig();
      expect(c.mimes, ['video/mp4']);
      expect(c.protocols, [7]);
      expect(c.placement, 3);
      expect(c.plcmt, 2);
      expect(c.startDelay, -1);
      expect(c.linearity, 1);
      expect(c.skippable, isTrue);
      expect(c.battr, [10, 11]);
      expect(c.minBitrate, 300);
      expect(c.maxBitrate, 1500);
      expect(c.maxDuration, 30);
    });

    test('toMap omits unset fields', () {
      expect(const VideoParameters(mimes: ['video/mp4']).toMap(), {
        'mimes': ['video/mp4'],
      });
      expect(_video.toMap(), containsPair('plcmt', 2));
      expect(_video.toMap(), containsPair('battr', [10, 11]));
    });
  });

  test('in-stream sends video parameters and maps exp', () async {
    final mockApi = MockInstreamVideoAdHostApi();
    PrebidInstreamVideoAd.api = mockApi;
    when(mockApi.fetchDemand(any, any)).thenAnswer(
      (_) async => MultiformatBidResult(
        resultCode: 'prebidDemandFetchSuccess',
        targetingKeywords: {'hb_pb': '0.10'},
        exp: 300,
      ),
    );

    final ad = PrebidInstreamVideoAd(
      configId: 'video',
      size: const Size(640, 480),
      videoParameters: _video,
    );
    final result = await ad.fetchDemand();

    final config =
        verify(mockApi.fetchDemand(any, captureAny)).captured.single
            as InstreamVideoAdRequestConfig;
    expect(config.videoConfig?.plcmt, 2);
    expect(config.videoConfig?.mimes, ['video/mp4']);
    expect(result.exp, 300);
    expect(result.targetingKeywords, {'hb_pb': '0.10'});
  });

  test('native response exposes privacy URL and every asset', () async {
    final mockApi = MockNativeAdHostApi();
    PrebidNativeAd.api = mockApi;
    PrebidNativeAdResponse? response;
    final ad = PrebidNativeAd(
      configId: 'native',
      listener: PrebidNativeAdListener(onAdLoaded: (r) => response = r),
    );
    await ad.loadAd();
    final adId = verify(mockApi.loadAd(captureAny, any)).captured.single as int;

    AdEventRouter.instance.onAdEvent(
      AdEvent(
        adId: adId,
        eventName: 'onAdLoaded',
        nativeAd: NativeAdData(
          title: 'Title',
          privacyUrl: 'https://privacy.example',
          titles: ['Title'],
          images: [NativeAdImageData(type: 3, url: 'https://img')],
          dataAssets: [
            NativeAdDataAssetData(type: 3, value: '4.5'),
            NativeAdDataAssetData(type: 6, value: r'$1.99'),
          ],
        ),
      ),
    );

    expect(response?.privacyUrl, 'https://privacy.example');
    expect(response?.titles, ['Title']);
    expect(response?.images.single.url, 'https://img');
    expect(response?.dataOf(NativeDataType.rating), ['4.5']);
    expect(response?.dataOf(NativeDataType.price), [r'$1.99']);
    await ad.destroy();
  });

  test('fullscreen controls carry supportSKOverlay', () {
    const controls = PrebidFullscreenControls(supportSKOverlay: true);
    expect(controls.toConfig().supportSKOverlay, isTrue);
    expect(controls.toMap(), {'supportSKOverlay': true});
  });

  test('initializeSdk forwards the non-tracking URL', () async {
    final mockApi = MockPrebidMobileHostApi();
    PrebidMobile.api = mockApi;
    when(
      mockApi.initializeSdk(any, any, any),
    ).thenAnswer((_) async => InitializationResult(status: 'succeeded'));

    await PrebidMobile.initializeSdk(
      prebidServerUrl: 'https://pbs',
      accountId: 'acc',
      nonTrackingUrl: 'https://pbs-no-track',
    );
    verify(
      mockApi.initializeSdk('https://pbs', 'acc', 'https://pbs-no-track'),
    ).called(1);
  });

  test('targeting sets source app and iTunes ID', () async {
    final mockApi = MockTargetingHostApi();
    PrebidTargeting.api = mockApi;
    await PrebidTargeting.setSourceApp('123456789');
    await PrebidTargeting.setItunesId('123456789');
    verify(mockApi.setSourceApp('123456789')).called(1);
    verify(mockApi.setItunesId('123456789')).called(1);
  });
}
