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

  test('a failure carries its message as the payload or its error', () {
    expect(adEventError('boom'), 'boom');
    expect(adEventError({'error': 'boom'}), 'boom');
    expect(adEventError({'error': 3}), 'Unknown error');
    expect(adEventError(null), 'Unknown error');
  });

  group('the channel maps the companion packages send', () {
    test('a native asset carries its type ids, unset fields left out', () {
      expect(const NativeAsset.title(required: true).toMap(), {
        'assetType': 'title',
        'required': true,
        'titleLength': 90,
      });
      expect(
        const NativeAsset.image(
          imageType: NativeImageType.icon,
          width: 80,
          height: 80,
          widthMin: 20,
          heightMin: 20,
          mimes: ['image/png'],
          ext: {'k': 1},
          assetExt: {'a': true},
        ).toMap(),
        {
          'assetType': 'image',
          'required': false,
          'imageType': 1,
          'imageWidth': 80,
          'imageHeight': 80,
          'imageWidthMin': 20,
          'imageHeightMin': 20,
          'imageMimes': ['image/png'],
          'ext': '{"k":1}',
          'assetExt': '{"a":true}',
        },
      );
      expect(
        const NativeAsset.data(
          dataType: NativeDataType.ctaText,
          length: 15,
        ).toMap(),
        {
          'assetType': 'data',
          'required': false,
          'dataType': 12,
          'dataLength': 15,
        },
      );
    });

    test('native parameters carry every set field', () {
      expect(const NativeParameters().toMap(), isEmpty);
      expect(
        const NativeParameters(
          assets: [NativeAsset.title()],
          eventTrackers: [
            NativeEventTracker(
              eventType: NativeEventType.impression,
              methods: [
                NativeEventTrackingMethod.image,
                NativeEventTrackingMethod.js,
              ],
              ext: {'t': 'x'},
            ),
          ],
          context: NativeContextType.contentCentric,
          contextSubType: NativeContextSubType.article,
          placementType: NativePlacementType.inFeed,
          placementCount: 2,
          sequence: 1,
          assetUrlSupport: true,
          dUrlSupport: false,
          privacy: true,
          ext: {'k': 1},
        ).toMap(),
        {
          'assets': [
            {'assetType': 'title', 'required': false, 'titleLength': 90},
          ],
          'eventTrackers': [
            {
              'eventType': 1,
              'methods': [1, 2],
              'ext': '{"t":"x"}',
            },
          ],
          'context': 1,
          'contextSubType': 11,
          'placementType': 1,
          'placementCount': 2,
          'sequence': 1,
          'assetUrlSupport': true,
          'dUrlSupport': false,
          'privacy': true,
          'ext': '{"k":1}',
        },
      );
    });

    test('video parameters carry every set field', () {
      expect(const VideoParameters(mimes: ['video/mp4']).toMap(), {
        'mimes': ['video/mp4'],
      });
      expect(
        const VideoParameters(
          mimes: ['video/mp4'],
          protocols: [VideoProtocol.vast2_0, VideoProtocol.vast4_0Wrapper],
          playbackMethods: [VideoPlaybackMethod.clickToPlay],
          placement: VideoPlacement.inFeed,
          maxDuration: 60,
          minDuration: 5,
          api: [VideoApi.mraid3, VideoApi.omid1],
          plcmt: VideoPlcmt.interstitial,
          startDelay: VideoStartDelay.preRoll,
          linearity: VideoLinearity.nonLinear,
          skippable: false,
          battr: [VideoCreativeAttribute.flash],
          minBitrate: 1,
          maxBitrate: 2,
          size: Size(400, 300),
        ).toMap(),
        {
          'mimes': ['video/mp4'],
          'protocols': [2, 8],
          'playbackMethods': [3],
          'placement': 4,
          'maxDuration': 60,
          'minDuration': 5,
          'api': [6, 7],
          'plcmt': 3,
          'startDelay': 0,
          'linearity': 2,
          'skippable': false,
          'battr': [17],
          'minBitrate': 1,
          'maxBitrate': 2,
          'width': 400,
          'height': 300,
        },
      );
    });

    test('fullscreen controls carry every set field', () {
      expect(const PrebidFullscreenControls().toMap(), isEmpty);
      expect(
        const PrebidFullscreenControls(
          closeButtonArea: 0.1,
          closeButtonPosition: PrebidButtonPosition.topLeft,
          skipButtonArea: 0.2,
          skipButtonPosition: PrebidButtonPosition.topRight,
          skipDelay: 4,
          isMuted: false,
          isSoundButtonVisible: true,
          isAutoCloseOnCompletionEnabled: true,
          minSizePercentage: Size(49.6, 70.2),
          supportSKOverlay: true,
        ).toMap(),
        {
          'closeButtonArea': 0.1,
          'closeButtonPosition': 'topLeft',
          'skipButtonArea': 0.2,
          'skipButtonPosition': 'topRight',
          'skipDelay': 4,
          'isMuted': false,
          'isSoundButtonVisible': true,
          'isAutoCloseOnCompletionEnabled': true,
          'minWidthPercentage': 50,
          'minHeightPercentage': 70,
          'supportSKOverlay': true,
        },
      );
    });
  });
}
