import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import 'channel_harness.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox(width: 400, child: Align(child: child)),
  ),
);

void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  group('PrebidMaxBannerAd', () {
    testWidgets('creation params', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_max/banner');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(
          const PrebidMaxBannerAd(
            configId: 'c',
            maxAdUnitId: 'u',
            width: 300,
            height: 250,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(views.creationParams, {
        'configId': 'c',
        'maxAdUnitId': 'u',
        'width': 300,
        'height': 250,
        'autoLoad': true,
      });
    }, variant: android);

    testWidgets('every event reaches its callback; onAdSize resizes', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_max/banner');
      addTearDown(views.dispose);
      final fired = <String>[];
      await tester.pumpWidget(
        _host(
          PrebidMaxBannerAd(
            configId: 'c',
            maxAdUnitId: 'u',
            width: 320,
            height: 50,
            listener: PrebidBannerAdListener(
              onAdLoaded: () => fired.add('loaded'),
              onAdDisplayed: () => fired.add('displayed'),
              onAdFailed: (e) => fired.add('failed:$e'),
              onAdClicked: () => fired.add('clicked'),
              onAdImpression: () => fired.add('impression'),
              onAdClosed: () => fired.add('closed'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final banner = find.byType(PrebidMaxBannerAd);
      expect(tester.getSize(banner), const Size(320, 50));
      await views.emit('onAdSize', {'width': 300.0, 'height': 250.0});
      await tester.pump();
      expect(tester.getSize(banner), const Size(300, 250));
      await views.emit('onAdSize', {'width': 300.0}); // incomplete: ignored
      await tester.pump();
      expect(tester.getSize(banner), const Size(300, 250));

      for (final e in [
        'onAdLoaded',
        'onAdDisplayed',
        'onAdImpression',
        'onAdClicked',
        'onAdClosed',
        'onUnknown',
      ]) {
        await views.emit(e);
      }
      await views.emit('onAdFailed', 'no fill');
      await views.emit('onAdFailed');
      expect(fired, [
        'loaded',
        'displayed',
        'impression',
        'clicked',
        'closed',
        'failed:no fill',
        'failed:',
      ]);
    }, variant: android);

    for (final variant in [android, ios]) {
      testWidgets('hears events the view sends while it is created', (
        tester,
      ) async {
        final views = PlatformViewHarness('prebid_mobile_sdk_max/banner')
          ..eventsOnCreate.add((
            'onAdFailed',
            'The Prebid SDK is not initialized',
          ));
        addTearDown(views.dispose);
        final fired = <String>[];
        await tester.pumpWidget(
          _host(
            PrebidMaxBannerAd(
              configId: 'c',
              maxAdUnitId: 'u',
              width: 320,
              height: 50,
              listener: PrebidBannerAdListener(
                onAdFailed: (e) => fired.add('failed:$e'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(fired, ['failed:The Prebid SDK is not initialized']);
        // Named by the channelId param, not the platform view id.
        expect(
          views.viewChannel,
          isNot('prebid_mobile_sdk_max/banner_${views.createdIds.single}'),
        );
      }, variant: variant);
    }

    testWidgets('a config change re-creates the view and its channel', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_max/banner');
      addTearDown(views.dispose);
      final controller = PrebidBannerAdController();
      var loaded = 0;
      Widget banner(String configId) => _host(
        PrebidMaxBannerAd(
          configId: configId,
          maxAdUnitId: 'u',
          width: 320,
          height: 50,
          controller: controller,
          listener: PrebidBannerAdListener(onAdLoaded: () => loaded++),
        ),
      );

      await tester.pumpWidget(banner('a'));
      await tester.pumpAndSettle();
      await views.emit('onAdSize', {'width': 300.0, 'height': 250.0});
      await tester.pump();
      final first = views.viewChannel!;

      await tester.pumpWidget(banner('a'));
      await tester.pumpAndSettle();
      expect(views.viewChannels, hasLength(1));

      await tester.pumpWidget(banner('b'));
      await tester.pumpAndSettle();
      expect(views.viewChannels, hasLength(2));
      expect(views.disposedIds, hasLength(1));
      expect(views.createdParams.last?['configId'], 'b');
      expect(
        tester.getSize(find.byType(PrebidMaxBannerAd)),
        const Size(320, 50),
      );

      await PlatformViewHarness.emitOn(first, 'onAdLoaded');
      expect(loaded, 0);
      await views.emit('onAdLoaded');
      expect(loaded, 1);

      await controller.stopRefresh();
      expect(views.calls.last.method, 'stopRefresh');
    }, variant: android);
  });

  group('PrebidMaxNativeAd', () {
    testWidgets('default creation params', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_max/native');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(const PrebidMaxNativeAd(configId: 'c', maxAdUnitId: 'u')),
      );
      await tester.pumpAndSettle();
      expect(views.creationParams, {'configId': 'c', 'maxAdUnitId': 'u'});
    }, variant: android);

    testWidgets('sends assets and trackers', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_max/native');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(
          const PrebidMaxNativeAd(
            configId: 'c',
            maxAdUnitId: 'u',
            assets: [
              NativeAsset.image(
                imageType: NativeImageType.icon,
                widthMin: 20,
                heightMin: 20,
                required: true,
              ),
            ],
            eventTrackers: [
              NativeEventTracker(
                eventType: NativeEventType.impression,
                methods: [
                  NativeEventTrackingMethod.image,
                  NativeEventTrackingMethod.js,
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(views.creationParams?['assets'], [
        {
          'assetType': 'image',
          'required': true,
          'imageType': 1,
          'imageWidthMin': 20,
          'imageHeightMin': 20,
        },
      ]);
      expect(views.creationParams?['eventTrackers'], [
        {
          'eventType': 1,
          'methods': [1, 2],
        },
      ]);
    }, variant: android);

    testWidgets('hears events the view sends while it is created', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_max/native')
        ..eventsOnCreate.add((
          'onAdFailed',
          'The Prebid SDK is not initialized',
        ));
      addTearDown(views.dispose);
      final fired = <String>[];
      await tester.pumpWidget(
        _host(
          PrebidMaxNativeAd(
            configId: 'c',
            maxAdUnitId: 'u',
            listener: PrebidMaxNativeAdListener(
              onAdFailed: (e) => fired.add('failed:$e'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fired, ['failed:The Prebid SDK is not initialized']);
    }, variant: android);

    testWidgets('every event reaches its callback; onAdSize resizes', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_max/native');
      addTearDown(views.dispose);
      final fired = <String>[];
      await tester.pumpWidget(
        _host(
          PrebidMaxNativeAd(
            configId: 'c',
            maxAdUnitId: 'u',
            height: 120,
            listener: PrebidMaxNativeAdListener(
              onAdLoaded: () => fired.add('loaded'),
              onAdImpression: () => fired.add('impression'),
              onAdClicked: () => fired.add('clicked'),
              onAdFailed: (e) => fired.add('failed:$e'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final native = find.byType(PrebidMaxNativeAd);
      expect(tester.getSize(native), const Size(400, 120));
      await views.emit('onAdSize', {'height': 280.0});
      await tester.pump();
      expect(tester.getSize(native), const Size(400, 280));
      await views.emit('onAdSize', {'height': -1.0}); // ignored
      await tester.pump();
      expect(tester.getSize(native).height, 280);

      for (final e in [
        'onAdLoaded',
        'onAdImpression',
        'onAdClicked',
        'onUnknown',
      ]) {
        await views.emit(e);
      }
      await views.emit('onAdFailed', 'No fill');
      await views.emit('onAdFailed');
      expect(fired, [
        'loaded',
        'impression',
        'clicked',
        'failed:No fill',
        'failed:',
      ]);
    }, variant: android);

    for (final variant in [android, ios]) {
      testWidgets('a config change re-creates the view and its channel', (
        tester,
      ) async {
        final views = PlatformViewHarness('prebid_mobile_sdk_max/native');
        addTearDown(views.dispose);
        final fired = <String>[];
        Widget native(String configId, {String? tag}) => _host(
          PrebidMaxNativeAd(
            configId: configId,
            maxAdUnitId: 'u',
            height: 100,
            listener: PrebidMaxNativeAdListener(
              onAdLoaded: () => fired.add('loaded:${tag ?? configId}'),
            ),
          ),
        );

        await tester.pumpWidget(native('a'));
        await tester.pumpAndSettle();
        final first = views.viewChannel!;
        await views.emit('onAdSize', {'height': 300.0});
        await tester.pump();
        await views.emit('onAdLoaded');

        // Same config, new listener: same view, the new listener is used.
        await tester.pumpWidget(native('a', tag: 'a2'));
        await tester.pumpAndSettle();
        expect(views.viewChannels, hasLength(1));
        await views.emit('onAdLoaded');

        await tester.pumpWidget(native('b'));
        await tester.pumpAndSettle();
        expect(views.viewChannels, hasLength(2));
        expect(views.disposedIds, hasLength(1));
        expect(views.creationParams?['configId'], 'b');
        expect(tester.getSize(find.byType(PrebidMaxNativeAd)).height, 100);

        await PlatformViewHarness.emitOn(first, 'onAdLoaded'); // ignored
        await views.emit('onAdLoaded');
        expect(fired, ['loaded:a', 'loaded:a2', 'loaded:b']);

        await tester.pumpWidget(_host(const SizedBox()));
        await views.emit('onAdLoaded');
        expect(fired, hasLength(3));
      }, variant: variant);
    }
  });
}
