import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

/// [a] and [b] are equal with equal hash codes; [c] differs from both.
void expectValue(Object a, Object b, Object c) {
  expect(a, b);
  expect(a.hashCode, b.hashCode);
  expect(a, isNot(c));
}

void main() {
  final at = DateTime(2026, 10, 11);

  test('bid responses compare by value, per type', () {
    PrebidBidResponse bid(String pb) => PrebidBidResponse(
      resultCode: 'prebidDemandFetchSuccess',
      targetingKeywords: {'hb_pb': pb},
      events: const {'ext.prebid.events.win': 'https://win'},
      exp: 300,
      receivedAt: at,
    );
    expectValue(bid('1.00'), bid('1.00'), bid('2.00'));

    const native = PrebidNativeBidResponse(
      resultCode: 'prebidDemandFetchSuccess',
      nativeAdCacheId: 'a',
    );
    expectValue(
      native,
      const PrebidNativeBidResponse(
        resultCode: 'prebidDemandFetchSuccess',
        nativeAdCacheId: 'a',
      ),
      const PrebidNativeBidResponse(
        resultCode: 'prebidDemandFetchSuccess',
        nativeAdCacheId: 'b',
      ),
    );
    // Same fields, another type.
    expect(
      const PrebidVideoAdBidResponse(resultCode: 'prebidDemandNoBids'),
      isNot(const PrebidBidResponse(resultCode: 'prebidDemandNoBids')),
    );
    expect(
      native.toString(),
      'PrebidNativeBidResponse(resultCode: prebidDemandFetchSuccess, '
      'topBidFiltered: false, events: {}, nativeAdCacheId: a)',
    );

    PrebidMultiformatBidResponse multi(String? format) =>
        PrebidMultiformatBidResponse(
          resultCode: 'prebidDemandFetchSuccess',
          winningFormat: format,
          receivedAt: at,
        );
    expectValue(multi('banner'), multi('banner'), multi('video'));
  });

  test('winning bids, rewards and external ids compare by value', () {
    PrebidWinningBid win(double price) => PrebidWinningBid(
      price: price,
      size: const Size(320, 50),
      bidder: 'appnexus',
      targetingKeywords: const {'hb_pb': '0.50'},
    );
    expectValue(win(0.5), win(0.5), win(0.6));
    expect(win(0.5).toString(), contains('bidder: appnexus'));

    PrebidReward reward(Object? nested) => PrebidReward(
      type: 'coins',
      count: 5,
      ext: {
        'a': {'b': nested},
      },
    );
    expectValue(reward([1, 2]), reward([1, 2]), reward([2, 1]));

    ExternalUserId eid(String id) => ExternalUserId(
      source: 'uidapi.com',
      identifier: id,
      atype: 3,
      ext: const {'rtiPartner': 'TDID'},
    );
    expectValue(eid('a'), eid('a'), eid('b'));
  });

  test('video parameters and fullscreen controls compare by value', () {
    VideoParameters video(int max) => VideoParameters(
      mimes: const ['video/mp4'],
      protocols: const [VideoProtocol.vast2_0],
      maxDuration: max,
      size: const Size(640, 480),
    );
    expectValue(video(30), video(30), video(60));
    expect(
      video(30).toString(),
      'VideoParameters(mimes: [video/mp4], protocols: [VideoProtocol.vast2_0], '
      'maxDuration: 30, size: Size(640.0, 480.0))',
    );

    PrebidFullscreenControls controls(int delay) => PrebidFullscreenControls(
      skipDelay: delay,
      closeButtonPosition: PrebidButtonPosition.topLeft,
    );
    expectValue(controls(3), controls(3), controls(4));
  });

  test('native parameters and responses compare by value', () {
    NativeParameters parameters(int length) => NativeParameters(
      assets: [
        NativeAsset.title(length: length, required: true),
        const NativeAsset.image(mimes: ['image/png']),
      ],
      eventTrackers: const [
        NativeEventTracker(
          eventType: NativeEventType.impression,
          methods: [NativeEventTrackingMethod.image],
        ),
      ],
      ext: {
        'k': [length],
      },
    );
    expectValue(parameters(90), parameters(90), parameters(25));
    expect(
      const NativeAsset.data(dataType: NativeDataType.rating).toString(),
      'NativeAsset(type: NativeAssetType.data, required: false, '
      'dataType: NativeDataType.rating)',
    );

    PrebidNativeAdResponse response(String title) => PrebidNativeAdResponse(
      title: title,
      images: const [PrebidNativeImage(type: 3, url: 'https://img')],
      dataAssets: const [PrebidNativeData(type: 3, value: '4.5')],
    );
    expectValue(response('a'), response('a'), response('b'));
  });
}
