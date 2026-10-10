import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

import 'mock_host_api.mocks.dart';
import 'platform_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeAdHostApi api;

  setUp(() {
    api = MockNativeAdHostApi();
    PrebidNativeAd.api = api;
  });

  NativeAdRequestConfig lastRequest() =>
      verify(api.loadAd(any, captureAny)).captured.single
          as NativeAdRequestConfig;

  Future<int> load(PrebidNativeAd ad) async {
    await ad.loadAd();
    return verify(api.loadAd(captureAny, any)).captured.last as int;
  }

  Future<void> send(int adId, String event, {String? error}) =>
      sendAdEvent(AdEvent(adId: adId, eventName: event, error: error));

  group('loadAd', () {
    test('sends the whole native request', () async {
      await PrebidNativeAd(
        configId: 'n',
        gpid: '/gpid',
        pbAdSlot: '/slot',
        impOrtbConfig: '{}',
        globalOrtbConfig: '{"app":{}}',
        nativeParameters: const NativeParameters(
          assets: [
            NativeAsset.title(length: 25, required: true),
            NativeAsset.image(
              imageType: NativeImageType.custom,
              width: 100,
              height: 50,
              widthMin: 10,
              heightMin: 5,
              mimes: ['image/png'],
              ext: {'k': 1},
              assetExt: {'a': 'b'},
            ),
            NativeAsset.data(dataType: NativeDataType.price, length: 8),
          ],
          eventTrackers: [
            NativeEventTracker(
              eventType: NativeEventType.viewable100,
              methods: [NativeEventTrackingMethod.custom],
              ext: {'t': 1},
            ),
          ],
          context: NativeContextType.product,
          contextSubType: NativeContextSubType.social,
          placementType: NativePlacementType.atomicUnit,
          placementCount: 2,
          sequence: 1,
          assetUrlSupport: true,
          dUrlSupport: false,
          privacy: true,
          ext: {'k': 1},
        ),
      ).loadAd();

      final c = lastRequest();
      expect(c.configId, 'n');
      expect(
        (c.gpid, c.pbAdSlot, c.impOrtbConfig, c.globalOrtbConfig),
        ('/gpid', '/slot', '{}', '{"app":{}}'),
      );
      final [title, image, data] = c.assets!;
      expect(
        (title!.assetType, title.required_, title.titleLength),
        ('title', true, 25),
      );
      expect((image!.assetType, image.imageType), ('image', 500));
      expect(
        (
          image.imageWidth,
          image.imageHeight,
          image.imageWidthMin,
          image.imageHeightMin,
        ),
        (100, 50, 10, 5),
      );
      expect(image.imageMimes, ['image/png']);
      expect((image.ext, image.assetExt), ('{"k":1}', '{"a":"b"}'));
      expect((data!.assetType, data.dataType, data.dataLength), ('data', 6, 8));
      final tracker = c.eventTrackers!.single!;
      expect(tracker.eventType, 3);
      expect(tracker.methods, [500]);
      expect(tracker.ext, '{"t":1}');
      expect(
        (c.context, c.contextSubType, c.placementType, c.placementCount),
        (3, 20, 2, 2),
      );
      expect(c.sequence, 1);
      expect(
        (c.assetUrlSupport, c.dUrlSupport, c.privacy),
        (true, false, true),
      );
      expect(c.ext, '{"k":1}');
    });

    test('requests the default assets when none are set', () async {
      await PrebidNativeAd(configId: 'n').loadAd();
      final assets = lastRequest().assets!;
      expect(
        assets.map((a) => (a!.assetType, a.required_, a.imageType, a.dataType)),
        [
          ('title', true, null, null),
          ('image', true, 3, null),
          ('image', true, 1, null),
          ('data', true, null, 1),
          ('data', false, null, 2),
          ('data', false, null, 12),
        ],
      );
      expect(assets.first!.titleLength, 90);
    });

    test('leaves unset ext fields out', () async {
      await PrebidNativeAd(
        configId: 'n',
        nativeParameters: const NativeParameters(assets: [NativeAsset.title()]),
      ).loadAd();
      final c = lastRequest();
      expect(
        (c.assets!.single!.ext, c.ext, c.eventTrackers),
        (null, null, null),
      );
    });
  });

  group('events', () {
    test('each one reaches its callback', () async {
      final events = <String>[];
      final ad = PrebidNativeAd(
        configId: 'n',
        listener: PrebidNativeAdListener(
          onAdLoaded: (r) => events.add('loaded:${r.title}'),
          onAdFailed: (e) => events.add('failed:$e'),
          onAdImpression: () => events.add('impression'),
          onAdClicked: () => events.add('clicked'),
          onAdExpired: () => events.add('expired'),
        ),
      );
      final id = await load(ad);

      await sendAdEvent(
        AdEvent(
          adId: id,
          eventName: 'onAdLoaded',
          nativeAd: NativeAdData(title: 'T'),
        ),
      );
      // A load event without the ad is ignored.
      await send(id, 'onAdLoaded');
      await send(id, 'onAdFailed', error: 'boom');
      await send(id, 'onAdFailed');
      await send(id, 'onAdImpression');
      await send(id, 'onAdClicked');
      await send(id, 'onAdExpired');
      await send(id, 'onUnknown');

      expect(events, [
        'loaded:T',
        'failed:boom',
        'failed:Unknown error',
        'impression',
        'clicked',
        'expired',
      ]);
    });

    test('the loaded ad carries every asset', () async {
      PrebidNativeAdResponse? response;
      final ad = PrebidNativeAd(
        configId: 'n',
        listener: PrebidNativeAdListener(onAdLoaded: (r) => response = r),
      );
      final id = await load(ad);
      await sendAdEvent(
        AdEvent(
          adId: id,
          eventName: 'onAdLoaded',
          nativeAd: NativeAdData(
            title: 'Title',
            text: 'Body',
            iconUrl: 'icon',
            imageUrl: 'image',
            sponsoredBy: 'Brand',
            callToAction: 'Install',
            clickUrl: 'click',
            privacyUrl: 'privacy',
            titles: ['Title', null],
            images: [
              NativeAdImageData(type: 3, url: 'https://img', width: 1200),
              null,
            ],
            dataAssets: [
              NativeAdDataAssetData(type: 3, value: '4.5'),
              NativeAdDataAssetData(type: 6, value: r'$1.99'),
            ],
          ),
        ),
      );

      final r = response!;
      expect(
        [r.title, r.text, r.iconUrl, r.imageUrl, r.sponsoredBy],
        ['Title', 'Body', 'icon', 'image', 'Brand'],
      );
      expect(
        [r.callToAction, r.clickUrl, r.privacyUrl],
        ['Install', 'click', 'privacy'],
      );
      expect(r.titles, ['Title']);
      final image = r.images.single;
      expect(
        (image.type, image.url, image.width, image.height),
        (3, 'https://img', 1200, null),
      );
      expect(r.dataOf(NativeDataType.rating), ['4.5']);
      expect(r.dataOf(NativeDataType.price), [r'$1.99']);
      expect(r.dataOf(NativeDataType.likes), isEmpty);
    });

    test('stop after destroy and come back with the next load', () async {
      final events = <String>[];
      final ad = PrebidNativeAd(
        configId: 'n',
        listener: PrebidNativeAdListener(
          onAdClicked: () => events.add('clicked'),
        ),
      );
      final id = await load(ad);

      await ad.destroy();
      verify(api.destroy(id)).called(1);
      await send(id, 'onAdClicked');
      expect(events, isEmpty);

      await load(ad);
      await send(id, 'onAdClicked');
      expect(events, ['clicked']);
    });
  });

  test('loads from a cache id and clicks the same ad', () async {
    when(api.performClick(any)).thenAnswer((_) async => true);
    final ad = PrebidNativeAd(configId: 'n');
    await ad.loadFromCacheId('cache-1');
    final adId =
        verify(api.loadFromCacheId(captureAny, 'cache-1')).captured.single
            as int;
    expect(await ad.performClick(), isTrue);
    verify(api.performClick(adId)).called(1);
  });

  test('dataOf skips data assets without a value', () {
    const response = PrebidNativeAdResponse(
      dataAssets: [
        PrebidNativeData(type: 3, value: '4.5'),
        PrebidNativeData(type: 3),
      ],
    );
    expect(response.dataOf(NativeDataType.rating), ['4.5']);
  });
}
