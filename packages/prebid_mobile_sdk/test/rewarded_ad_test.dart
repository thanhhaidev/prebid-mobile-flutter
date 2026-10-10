import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

import 'mock_host_api.mocks.dart';
import 'platform_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRewardedAdHostApi api;

  setUp(() {
    api = MockRewardedAdHostApi();
    PrebidRewardedAd.api = api;
  });

  List<Object?> lastLoad() => verify(
    api.loadAd(
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

  Future<int> load(PrebidRewardedAd ad) async {
    await ad.loadAd();
    return lastLoad()[0]! as int;
  }

  Future<void> send(int adId, String event, {RewardData? reward}) =>
      sendAdEvent(AdEvent(adId: adId, eventName: event, reward: reward));

  test('loadAd sends the whole request', () async {
    await PrebidRewardedAd(
      configId: 'r',
      adFormats: const {PrebidAdFormat.video},
      videoParameters: const VideoParameters(
        mimes: ['video/mp4'],
        size: Size(640, 480),
      ),
      impOrtbConfig: '{}',
      globalOrtbConfig: '{"app":{}}',
      pbAdSlot: '/r',
      gpid: '/1/rewarded',
      adPosition: PrebidAdPosition.header,
      controls: const PrebidFullscreenControls(isMuted: true),
    ).loadAd();

    final args = lastLoad();
    expect(args[1], 'r');
    expect(args[2], ['video']);
    final video = args[3]! as VideoParametersConfig;
    expect(video.mimes, ['video/mp4']);
    expect((video.width, video.height), (640, 480));
    expect(args[4], '{"ext":{"gpid":"/1/rewarded"}}');
    expect(args[5], '{"app":{}}');
    expect((args[6]! as FullscreenControlsConfig).isMuted, isTrue);
    expect(args[7], '/r');
    expect(args[8], 4);
  });

  test('each event reaches its callback', () async {
    final events = <String>[];
    final ad = PrebidRewardedAd(
      configId: 'r',
      listener: PrebidRewardedAdListener(
        onAdLoaded: () => events.add('loaded'),
        onAdFailed: (e) => events.add('failed:$e'),
        onAdDisplayed: () => events.add('displayed'),
        onAdClosed: () => events.add('closed'),
        onAdClicked: () => events.add('clicked'),
        onUserEarnedReward: (r) => events.add('reward:${r.count}x${r.type}'),
        onAdExpired: () => events.add('expired'),
        onAdImpression: () => events.add('impression'),
      ),
    );
    final id = await load(ad);

    await send(id, 'onAdLoaded');
    await sendAdEvent(AdEvent(adId: id, eventName: 'onAdFailed', error: 'x'));
    await send(id, 'onAdFailed');
    await send(id, 'onAdDisplayed');
    await send(id, 'onAdClosed');
    await send(id, 'onAdClicked');
    await send(
      id,
      'onUserEarnedReward',
      reward: RewardData(type: 'coins', count: 5),
    );
    await send(id, 'onAdExpired');
    await send(id, 'onAdImpression');
    await send(id, 'onUnknown');

    expect(events, [
      'loaded',
      'failed:x',
      'failed:Unknown error',
      'displayed',
      'closed',
      'clicked',
      'reward:5xcoins',
      'expired',
      'impression',
    ]);
  });

  test('the reward keeps its ext; missing values take the defaults', () async {
    final rewards = <PrebidReward>[];
    final ad = PrebidRewardedAd(
      configId: 'r',
      listener: PrebidRewardedAdListener(onUserEarnedReward: rewards.add),
    );
    final id = await load(ad);

    await send(
      id,
      'onUserEarnedReward',
      reward: RewardData(
        type: 'gems',
        count: 3,
        ext: {'bonus': true, null: 'x'},
      ),
    );
    await send(id, 'onUserEarnedReward', reward: RewardData());
    await send(id, 'onUserEarnedReward');

    expect(rewards.map((r) => (r.type, r.count)), [
      ('gems', 3),
      ('reward', 1),
      ('reward', 1),
    ]);
    expect(rewards.map((r) => r.ext), [
      {'bonus': true, '': 'x'},
      null,
      null,
    ]);
  });

  test('isLoaded follows the load, the show and a close', () async {
    final ad = PrebidRewardedAd(configId: 'r');
    final id = await load(ad);
    await send(id, 'onAdLoaded');
    expect(ad.isLoaded, isTrue);
    await ad.show();
    verify(api.show(id)).called(1);
    expect(ad.isLoaded, isFalse);

    await send(id, 'onAdLoaded');
    await send(id, 'onAdClosed');
    expect(ad.isLoaded, isFalse);
  });

  test('events stop after destroy and come back with the next load', () async {
    final events = <String>[];
    final ad = PrebidRewardedAd(
      configId: 'r',
      listener: PrebidRewardedAdListener(
        onAdLoaded: () => events.add('loaded'),
      ),
    );
    final id = await load(ad);

    await ad.destroy();
    verify(api.destroy(id)).called(1);
    await send(id, 'onAdLoaded');
    expect(events, isEmpty);

    await load(ad);
    await send(id, 'onAdLoaded');
    expect(events, ['loaded']);
  });

  test('winningBid is the loaded bid, cleared by the next load', () async {
    final ad = PrebidRewardedAd(configId: 'r');
    final id = await load(ad);
    await sendAdEvent(
      AdEvent(
        adId: id,
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
    expect(ad.winningBid?.bidder, isNull);

    await ad.loadAd();
    expect(ad.winningBid, isNull);
  });
}
