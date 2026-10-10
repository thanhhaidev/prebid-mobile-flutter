import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

/// The values the enums carry to the platforms (OpenRTB codes), as literals.
void main() {
  test('PrebidAdPosition', () {
    expect(
      {for (final p in PrebidAdPosition.values) p.name: p.value},
      {
        'undefined': -1,
        'unknown': 0,
        'aboveTheFold': 1,
        'belowTheFold': 3,
        'header': 4,
        'footer': 5,
        'sidebar': 6,
        'fullScreen': 7,
      },
    );
  });

  test('native enums', () {
    expect(NativeImageType.values.map((e) => e.value), [1, 3, 500]);
    expect(NativeDataType.values.map((e) => e.value), [
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 500, //
    ]);
    expect(NativeEventType.values.map((e) => e.value), [1, 2, 3, 4, 500]);
    expect(NativeEventTrackingMethod.values.map((e) => e.value), [1, 2, 500]);
    expect(NativeContextType.values.map((e) => e.value), [1, 2, 3, 500]);
    expect(NativeContextSubType.values.map((e) => e.value), [
      10, 11, 12, 13, 14, 15, 20, 21, 22, 30, 31, 32, 500, //
    ]);
    expect(NativePlacementType.values.map((e) => e.value), [1, 2, 3, 4, 500]);
  });

  test('video enums', () {
    expect(VideoProtocol.values.map((e) => e.value), [1, 2, 3, 4, 5, 6, 7, 8]);
    expect(VideoPlaybackMethod.values.map((e) => e.value), [1, 2, 3, 4, 5, 6]);
    expect(VideoPlacement.values.map((e) => e.value), [1, 2, 3, 4, 5]);
    expect(VideoApi.values.map((e) => e.value), [1, 2, 3, 4, 5, 6, 7]);
    expect(VideoPlcmt.values.map((e) => e.value), [1, 2, 3, 4]);
    expect(VideoLinearity.values.map((e) => e.value), [1, 2]);
    expect(VideoCreativeAttribute.values.map((e) => e.value), [
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, //
    ]);
    expect(
      [
        VideoStartDelay.preRoll,
        VideoStartDelay.genericMidRoll,
        VideoStartDelay.genericPostRoll,
      ],
      [0, -1, -2],
    );
  });
}
