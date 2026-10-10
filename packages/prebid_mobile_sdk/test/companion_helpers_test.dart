import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

void main() {
  group('Channel maps used by the companion packages', () {
    test('NativeAsset.toMap carries type ids and omits unset fields', () {
      expect(const NativeAsset.title(required: true).toMap(), {
        'assetType': 'title',
        'required': true,
        'titleLength': 90,
      });
      expect(
        const NativeAsset.image(
          imageType: NativeImageType.icon,
          widthMin: 20,
          heightMin: 20,
        ).toMap(),
        {
          'assetType': 'image',
          'required': false,
          'imageType': NativeImageType.icon.value,
          'imageWidthMin': 20,
          'imageHeightMin': 20,
        },
      );
      expect(const NativeAsset.data(dataType: NativeDataType.ctaText).toMap(), {
        'assetType': 'data',
        'required': false,
        'dataType': NativeDataType.ctaText.value,
      });
    });

    test('NativeAsset / NativeEventTracker toMap carry ext as JSON', () {
      expect(
        const NativeAsset.image(
          mimes: ['image/png'],
          ext: {'k': 1},
          assetExt: {'a': true},
        ).toMap(),
        containsPair('ext', '{"k":1}'),
      );
      expect(
        const NativeAsset.data(
          dataType: NativeDataType.desc,
          assetExt: {'a': true},
        ).toMap(),
        allOf(containsPair('assetExt', '{"a":true}'), isNot(contains('ext'))),
      );
      expect(
        const NativeAsset.image(mimes: ['image/png']).toMap(),
        containsPair('imageMimes', ['image/png']),
      );
      expect(
        const NativeEventTracker(
          eventType: NativeEventType.impression,
          methods: [NativeEventTrackingMethod.image],
          ext: {'t': 'x'},
        ).toMap(),
        containsPair('ext', '{"t":"x"}'),
      );
    });

    test('NativeParameters.toMap omits unset fields', () {
      expect(const NativeParameters().toMap(), isEmpty);
      expect(
        const NativeParameters(
          assets: [NativeAsset.title()],
          eventTrackers: [
            NativeEventTracker(
              eventType: NativeEventType.impression,
              methods: [NativeEventTrackingMethod.image],
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
          'assets': [const NativeAsset.title().toMap()],
          'eventTrackers': [
            {
              'eventType': NativeEventType.impression.value,
              'methods': [NativeEventTrackingMethod.image.value],
            },
          ],
          'context': NativeContextType.contentCentric.value,
          'contextSubType': NativeContextSubType.article.value,
          'placementType': NativePlacementType.inFeed.value,
          'placementCount': 2,
          'sequence': 1,
          'assetUrlSupport': true,
          'dUrlSupport': false,
          'privacy': true,
          'ext': '{"k":1}',
        },
      );
    });

    test('NativeEventTracker.toMap carries ids', () {
      const tracker = NativeEventTracker(
        eventType: NativeEventType.impression,
        methods: [
          NativeEventTrackingMethod.image,
          NativeEventTrackingMethod.js,
        ],
      );
      expect(tracker.toMap(), {
        'eventType': NativeEventType.impression.value,
        'methods': [
          NativeEventTrackingMethod.image.value,
          NativeEventTrackingMethod.js.value,
        ],
      });
    });
  });

  group('PrebidBannerVideoListener.dispatch', () {
    test('routes video events and reports unknown names', () {
      final fired = <String>[];
      final listener = PrebidBannerVideoListener(
        onVideoCompleted: () => fired.add('completed'),
        onVideoPaused: () => fired.add('paused'),
        onVideoResumed: () => fired.add('resumed'),
        onVideoMuted: () => fired.add('muted'),
        onVideoUnmuted: () => fired.add('unmuted'),
      );
      for (final e in [
        'onVideoCompleted',
        'onVideoPaused',
        'onVideoResumed',
        'onVideoMuted',
        'onVideoUnmuted',
      ]) {
        expect(listener.dispatch(e), isTrue);
      }
      expect(listener.dispatch('onAdLoaded'), isFalse);
      expect(fired, ['completed', 'paused', 'resumed', 'muted', 'unmuted']);
    });
  });
}
