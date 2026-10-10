import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/companion.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

class _TestAd extends CompanionFullscreenAd {
  _TestAd(super.channel, this.listener);

  final PrebidRewardedAdListener listener;

  @override
  Map<String, Object?> get loadArguments => {'configId': 'c'};

  @override
  void onEvent(String event, Map? args) =>
      dispatchRewardedEvent(listener, event, args);

  int get id => adId;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();

  Future<void> emit(String channel, String method, Map args) =>
      messenger.handlePlatformMessage(
        channel,
        codec.encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );

  test('releases the native ads once, before the first call', () async {
    final calls = <String>[];
    final channel = CompanionAdChannel('test/a');
    messenger.setMockMethodCallHandler(channel.methodChannel, (call) async {
      calls.add(call.method);
      return null;
    });
    final ad = _TestAd(channel, const PrebidRewardedAdListener());
    await ad.loadAd();
    await ad.show();
    await ad.destroy();
    expect(calls, ['releaseAll', 'load', 'show', 'destroy']);
  });

  test('a missing releaseAll on the native side is not an error', () async {
    final calls = <MethodCall>[];
    final channel = CompanionAdChannel('test/b');
    messenger.setMockMethodCallHandler(channel.methodChannel, (call) async {
      if (call.method == 'releaseAll') throw MissingPluginException();
      calls.add(call);
      return null;
    });
    final ad = _TestAd(channel, const PrebidRewardedAdListener());
    await ad.loadAd();
    expect(calls.single.method, 'load');
    expect(calls.single.arguments, {'adId': ad.id, 'configId': 'c'});
  });

  test('routes events by ad id and tracks isLoaded', () async {
    final channel = CompanionAdChannel('test/c');
    messenger.setMockMethodCallHandler(
      channel.methodChannel,
      (_) async => null,
    );
    final events = <String>[];
    PrebidReward? reward;
    final a = _TestAd(
      channel,
      PrebidRewardedAdListener(
        onAdLoaded: () => events.add('a loaded'),
        onAdFailed: (e) => events.add('a failed: $e'),
        onUserEarnedReward: (r) => reward = r,
      ),
    );
    final b = _TestAd(
      channel,
      PrebidRewardedAdListener(onAdLoaded: () => events.add('b loaded')),
    );
    await a.loadAd();
    await b.loadAd();

    await emit('test/c', 'onAdLoaded', {'adId': a.id});
    expect(a.isLoaded, isTrue);
    expect(b.isLoaded, isFalse);

    await emit('test/c', 'onUserEarnedReward', {
      'adId': a.id,
      'rewardType': 'coins',
      'rewardCount': 5,
      'rewardExt': '{"k":1}',
    });
    expect(reward?.type, 'coins');
    expect(reward?.count, 5);
    expect(reward?.ext, {'k': 1});

    await emit('test/c', 'onAdFailed', {'adId': a.id});
    expect(a.isLoaded, isFalse);

    await b.destroy();
    await emit('test/c', 'onAdLoaded', {'adId': b.id});
    expect(events, ['a loaded', 'a failed: Unknown error']);
  });

  test('a malformed reward ext keeps the reward', () {
    final reward = rewardFromPayload({'rewardExt': '{not json'});
    expect(reward.type, 'reward');
    expect(reward.count, 1);
    expect(reward.ext, isNull);
  });

  test('AdViewChannel names the channel before the view exists', () async {
    final received = <String>[];
    final view = AdViewChannel('test/view', (call) async {
      received.add(call.method);
    });
    await emit('test/view_${view.id}', 'onAdLoaded', {});
    view.dispose();
    await emit('test/view_${view.id}', 'onAdLoaded', {});
    expect(received, ['onAdLoaded']);
    expect(AdViewChannel('test/view', (_) async {}).id, isNot(view.id));
  });
}
