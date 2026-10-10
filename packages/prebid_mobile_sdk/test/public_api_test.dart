import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';
import 'package:prebid_mobile_sdk/src/internal/pigeon_conversions.dart';

import 'mock_host_api.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Whether a symbol is *not* exported can't be asserted by compiling a
  // test, so check the library's export list and the exported sources.
  group('public library surface', () {
    final library = File('lib/prebid_mobile_sdk.dart').readAsStringSync();
    final exported = RegExp(
      "^export '([^']+)'",
      multiLine: true,
    ).allMatches(library).map((m) => m.group(1)!).toList();

    test('does not export generated or internal files', () {
      expect(exported, isNotEmpty);
      for (final path in exported) {
        expect(path, isNot(contains('generated/')));
        expect(path, isNot(contains('internal/')));
        expect(path, isNot(endsWith('ad_event_router.dart')));
        expect(path, isNot(endsWith('multiformat_event_router.dart')));
      }
    });

    test('exported files declare no routers or Pigeon conversions', () {
      for (final path in exported) {
        final source = File('lib/$path').readAsStringSync();
        expect(
          source,
          isNot(contains('class MultiformatEventRouter')),
          reason: path,
        );
        expect(source, isNot(contains('class AdEventRouter')), reason: path);
        expect(source, isNot(contains(' toConfig(')), reason: path);
        expect(source, isNot(contains('fromMap(')), reason: path);
      }
    });
  });

  group('Pigeon conversions', () {
    test('VideoParameters.toConfig carries every field', () {
      const params = VideoParameters(
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
      );
      final c = params.toConfig();
      expect(c.mimes, ['video/mp4']);
      expect(c.protocols, [2, 8]);
      expect(c.playbackMethods, [3]);
      expect(c.placement, 4);
      expect(c.maxDuration, 60);
      expect(c.minDuration, 5);
      expect(c.api, [6, 7]);
      expect(c.plcmt, 3);
      expect(c.startDelay, 0);
      expect(c.linearity, 2);
      expect(c.skippable, isFalse);
      expect(c.battr, [17]);
      expect(c.minBitrate, 1);
      expect(c.maxBitrate, 2);
      expect(params.toMap(), {
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
      });
    });

    test('unset VideoParameters fields stay null', () {
      final c = const VideoParameters(mimes: []).toConfig();
      expect(c.protocols, isNull);
      expect(c.plcmt, isNull);
      expect(c.battr, isNull);
    });

    test('PrebidFullscreenControls.toConfig / toMap carry every field', () {
      const controls = PrebidFullscreenControls(
        closeButtonArea: 0.1,
        closeButtonPosition: PrebidButtonPosition.topLeft,
        skipButtonArea: 0.2,
        skipButtonPosition: PrebidButtonPosition.topRight,
        skipDelay: 4,
        isMuted: false,
        isSoundButtonVisible: true,
        isAutoCloseOnCompletionEnabled: true,
        minSizePercentage: Size(49.6, 70.2),
        supportSKOverlay: false,
      );
      final c = controls.toConfig();
      expect(c.closeButtonArea, 0.1);
      expect(c.closeButtonPosition, 'topLeft');
      expect(c.skipButtonArea, 0.2);
      expect(c.skipButtonPosition, 'topRight');
      expect(c.skipDelay, 4);
      expect(c.isMuted, isFalse);
      expect(c.isSoundButtonVisible, isTrue);
      expect(c.isAutoCloseOnCompletionEnabled, isTrue);
      expect(c.minWidthPercentage, 50);
      expect(c.minHeightPercentage, 70);
      expect(c.supportSKOverlay, isFalse);
      expect(controls.toMap(), {
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
        'supportSKOverlay': false,
      });
      expect(const PrebidFullscreenControls().toMap(), isEmpty);
    });

    test('NativeAsset / NativeEventTracker toConfig match toMap', () {
      const assets = [
        NativeAsset.title(length: 25, required: true),
        NativeAsset.image(
          imageType: NativeImageType.custom,
          width: 100,
          height: 50,
          widthMin: 10,
          heightMin: 5,
        ),
        NativeAsset.data(dataType: NativeDataType.price, length: 8),
      ];
      for (final a in assets) {
        final c = a.toConfig();
        final m = a.toMap();
        expect(c.assetType, m['assetType']);
        expect(c.required_, m['required']);
        expect(c.titleLength, m['titleLength']);
        expect(c.imageType, m['imageType']);
        expect(c.imageWidth, m['imageWidth']);
        expect(c.imageHeight, m['imageHeight']);
        expect(c.imageWidthMin, m['imageWidthMin']);
        expect(c.imageHeightMin, m['imageHeightMin']);
        expect(c.dataType, m['dataType']);
        expect(c.dataLength, m['dataLength']);
      }
      expect(assets[1].toConfig().imageType, 500);
      expect(assets[2].toConfig().dataType, 6);

      const tracker = NativeEventTracker(
        eventType: NativeEventType.viewable100,
        methods: [NativeEventTrackingMethod.custom],
      );
      expect(tracker.toConfig().eventType, 3);
      expect(tracker.toConfig().methods, [500]);
    });

    test('stringMap drops null keys and values', () {
      expect(stringMap(null), isNull);
      expect(stringMap({'a': '1', 'b': null, null: '2'}), {'a': '1'});
    });
  });

  group('enum wire values', () {
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
      expect(NativeAssetType.values.map((e) => e.name), [
        'title',
        'image',
        'data',
      ]);
    });

    test('video enums', () {
      expect(VideoProtocol.values.map((e) => e.value), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
      ]);
      expect(VideoPlaybackMethod.values.map((e) => e.value), [
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
      expect(VideoPlacement.values.map((e) => e.value), [1, 2, 3, 4, 5]);
      expect(VideoApi.values.map((e) => e.value), [1, 2, 3, 4, 5, 6, 7]);
      expect(VideoPlcmt.values.map((e) => e.value), [1, 2, 3, 4]);
      expect(VideoLinearity.values.map((e) => e.value), [1, 2]);
      expect(
        VideoCreativeAttribute.values.map((e) => e.value),
        List.generate(17, (i) => i + 1),
      );
      expect(VideoStartDelay.genericMidRoll, -1);
      expect(VideoStartDelay.genericPostRoll, -2);
      expect(VideoPlacementType.values.map((e) => e.name), [
        'inBanner',
        'inArticle',
        'inFeed',
      ]);
    });

    test('PrebidEidsPlacement names', () {
      expect(PrebidEidsPlacement.values.map((e) => e.name), [
        'openRtb26',
        'openRtb25',
        'compatible',
      ]);
    });
  });

  group('PrebidMobile', () {
    late MockPrebidMobileHostApi api;

    setUp(() {
      api = MockPrebidMobileHostApi();
      PrebidMobile.api = api;
    });

    test('initializeSdk maps every status and the error', () async {
      final results = <(PrebidInitializationStatus, String?)>[];
      for (final (status, error) in [
        ('succeeded', null),
        ('serverStatusWarning', 'warn'),
        ('failed', 'down'),
        ('somethingNew', null),
      ]) {
        when(api.initializeSdk(any, any, any)).thenAnswer(
          (_) async => InitializationResult(status: status, error: error),
        );
        await PrebidMobile.initializeSdk(
          prebidServerUrl: 'u',
          accountId: 'a',
          completion: (s, e) => results.add((s, e)),
        );
      }
      expect(results, [
        (PrebidInitializationStatus.succeeded, null),
        (PrebidInitializationStatus.serverStatusWarning, 'warn'),
        (PrebidInitializationStatus.failed, 'down'),
        (PrebidInitializationStatus.failed, null),
      ]);
      expect(PrebidMobile.isSdkInitialized, isFalse);
    });

    test('setLogLevel sends the level index', () async {
      for (final level in PrebidLogLevel.values) {
        await PrebidMobile.setLogLevel(level);
        verify(api.setLogLevel(level.index)).called(1);
      }
    });

    test('setEidsPlacement sends the placement name', () async {
      for (final p in PrebidEidsPlacement.values) {
        await PrebidMobile.setEidsPlacement(p);
        verify(api.setEidsPlacement(p.name)).called(1);
      }
    });

    test('setAuctionSettingsId(null) clears it', () async {
      await PrebidMobile.setAuctionSettingsId(null);
      verify(api.setAuctionSettingsId(null)).called(1);
    });

    test('getSharedId returns null when unset', () async {
      when(api.getSharedId()).thenAnswer((_) async => null);
      expect(await PrebidMobile.getSharedId(), isNull);
    });

    test('external user ids carry ext both ways', () async {
      await PrebidMobile.setExternalUserIds(const [
        ExternalUserId(source: 's', identifier: 'i', ext: {'k': 1}),
      ]);
      final sent =
          verify(api.setExternalUserIds(captureAny)).captured.single
              as List<ExternalUserIdData>;
      expect(sent.single.ext, {'k': 1});

      when(api.getExternalUserIds()).thenAnswer(
        (_) async => [
          ExternalUserIdData(
            source: 's',
            identifier: 'i',
            atype: 2,
            ext: {'k': 1, null: 'x'},
          ),
        ],
      );
      final ids = await PrebidMobile.getExternalUserIds();
      expect(ids.single.source, 's');
      expect(ids.single.identifier, 'i');
      expect(ids.single.atype, 2);
      expect(ids.single.ext, {'k': 1, '': 'x'});
    });
  });

  group('response types', () {
    test('isSuccess follows the result code', () {
      expect(
        const PrebidBidResponse(
          resultCode: 'prebidDemandFetchSuccess',
        ).isSuccess,
        isTrue,
      );
      expect(
        const PrebidBidResponse(resultCode: 'prebidDemandNoBids').isSuccess,
        isFalse,
      );
      expect(
        const PrebidMultiformatBidResponse(
          resultCode: 'prebidDemandFetchSuccess',
        ).isSuccess,
        isTrue,
      );
      expect(
        const PrebidVideoAdBidResponse(
          resultCode: 'prebidDemandTimedOut',
        ).isSuccess,
        isFalse,
      );
      expect(
        const PrebidMultiformatBidResponse(resultCode: 'x').topBidFiltered,
        isFalse,
      );
    });

    test('PrebidNativeAdResponse.dataOf filters by type', () {
      const response = PrebidNativeAdResponse(
        dataAssets: [
          PrebidNativeData(type: 3, value: '4.5'),
          PrebidNativeData(type: 3),
          PrebidNativeData(type: 6, value: r'$1'),
        ],
      );
      expect(response.dataOf(NativeDataType.rating), ['4.5']);
      expect(response.dataOf(NativeDataType.price), [r'$1']);
      expect(response.dataOf(NativeDataType.likes), isEmpty);
    });
  });

  group('in-stream video ad', () {
    test('sends the size and destroys', () async {
      final api = MockInstreamVideoAdHostApi();
      PrebidInstreamVideoAd.api = api;
      when(api.fetchDemand(any, any)).thenAnswer(
        (_) async => MultiformatBidResult(resultCode: 'prebidDemandNoBids'),
      );
      final ad = PrebidInstreamVideoAd(
        configId: 'v',
        size: const Size(640, 360),
      );
      final result = await ad.fetchDemand();
      final captured = verify(api.fetchDemand(captureAny, captureAny)).captured;
      final config = captured[1] as InstreamVideoAdRequestConfig;
      expect(config.width, 640);
      expect(config.height, 360);
      expect(config.videoConfig, isNull);
      expect(result.isSuccess, isFalse);
      expect(result.targetingKeywords, isNull);

      await ad.destroy();
      verify(api.destroy(captured[0] as int)).called(1);
    });
  });
}
