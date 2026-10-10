import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

import 'mock_host_api.mocks.dart';
import 'platform_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockInterstitialAdHostApi interstitials;
  late MockRewardedAdHostApi rewardeds;

  setUp(() {
    interstitials = MockInterstitialAdHostApi();
    rewardeds = MockRewardedAdHostApi();
    PrebidInterstitialAd.api = interstitials;
    PrebidRewardedAd.api = rewardeds;
  });

  /// The `loadAd` arguments of the last interstitial load.
  List<Object?> interstitialLoad() => verify(
    interstitials.loadAd(
      captureAny,
      captureAny,
      captureAny,
      captureAny,
      captureAny,
      captureAny,
      captureAny,
      captureAny,
      captureAny,
    ),
  ).captured;

  group('the ad position', () {
    test('an interstitial sends its OpenRTB value', () async {
      await PrebidInterstitialAd(
        configId: 'c',
        adPosition: PrebidAdPosition.fullScreen,
      ).loadAd();
      expect(interstitialLoad()[8], 7);
    });

    test('a rewarded ad sends it too', () async {
      await PrebidRewardedAd(
        configId: 'c',
        adPosition: PrebidAdPosition.header,
      ).loadAd();
      final captured = verify(
        rewardeds.loadAd(any, any, any, any, any, any, any, any, captureAny),
      ).captured;
      expect(captured.single, 4);
    });

    test('is omitted when unset', () async {
      await PrebidInterstitialAd(configId: 'c').loadAd();
      expect(interstitialLoad()[8], isNull);
    });
  });

  group('the GPID', () {
    test('becomes imp.ext.gpid when there is no impression config', () async {
      await PrebidInterstitialAd(configId: 'c', gpid: '/1/home').loadAd();
      expect(jsonDecode(interstitialLoad()[4]! as String), {
        'ext': {'gpid': '/1/home'},
      });
    });

    test('joins the impression config, keeping its keys', () async {
      await PrebidInterstitialAd(
        configId: 'c',
        gpid: '/1/home',
        impOrtbConfig: '{"instl":1,"ext":{"data":{"k":"v"}}}',
      ).loadAd();
      expect(jsonDecode(interstitialLoad()[4]! as String), {
        'instl': 1,
        'ext': {
          'gpid': '/1/home',
          'data': {'k': 'v'},
        },
      });
    });

    test('gives way to a gpid the impression config already sets', () async {
      await PrebidInterstitialAd(
        configId: 'c',
        gpid: '/1/home',
        impOrtbConfig: '{"ext":{"gpid":"/1/own"}}',
      ).loadAd();
      expect(jsonDecode(interstitialLoad()[4]! as String), {
        'ext': {'gpid': '/1/own'},
      });
    });

    test('leaves an impression config that is not JSON as it is', () async {
      await PrebidInterstitialAd(
        configId: 'c',
        gpid: '/1/home',
        impOrtbConfig: 'not json',
      ).loadAd();
      expect(interstitialLoad()[4], 'not json');
    });
  });

  group('the winning bid', () {
    test('is read from the loaded event', () async {
      final ad = PrebidInterstitialAd(configId: 'c');
      await ad.loadAd();
      final adId = interstitialLoad()[0]! as int;

      await sendAdEvent(
        AdEvent(
          adId: adId,
          eventName: 'onAdLoaded',
          winningBid: WinningBidData(
            price: 1.25,
            bidder: 'appnexus',
            width: 320,
            height: 480,
            targetingKeywords: {'hb_pb': '1.20'},
          ),
        ),
      );

      final bid = ad.winningBid!;
      expect(bid.price, 1.25);
      expect(bid.bidder, 'appnexus');
      expect(bid.size, const Size(320, 480));
      expect(bid.targetingKeywords, {'hb_pb': '1.20'});
    });

    test('is null when the platform sends none, and after a reload', () async {
      final ad = PrebidRewardedAd(configId: 'c');
      await ad.loadAd();
      final adId =
          verify(
                rewardeds.loadAd(
                  captureAny,
                  any,
                  any,
                  any,
                  any,
                  any,
                  any,
                  any,
                  any,
                ),
              ).captured.single
              as int;
      await sendAdEvent(
        AdEvent(
          adId: adId,
          eventName: 'onAdLoaded',
          winningBid: WinningBidData(
            price: 2,
            width: 300,
            height: 250,
            targetingKeywords: {},
          ),
        ),
      );
      expect(ad.winningBid?.price, 2);

      await ad.loadAd();
      expect(ad.winningBid, isNull);
      await sendAdEvent(AdEvent(adId: adId, eventName: 'onAdLoaded'));
      expect(ad.winningBid, isNull);
    });
  });
}
