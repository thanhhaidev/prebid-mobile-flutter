import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';

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

  group('PrebidAdMobBannerAd', () {
    testWidgets('creation params', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_admob/banner');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(
          const PrebidAdMobBannerAd(
            configId: 'c',
            adMobAdUnitId: 'u',
            width: 300,
            height: 250,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(views.creationParams, {
        'configId': 'c',
        'adMobAdUnitId': 'u',
        'width': 300,
        'height': 250,
        'autoLoad': true,
      });
    }, variant: android);

    testWidgets('every event reaches its callback; onAdSize resizes', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_admob/banner');
      addTearDown(views.dispose);
      final fired = <String>[];
      await tester.pumpWidget(
        _host(
          PrebidAdMobBannerAd(
            configId: 'c',
            adMobAdUnitId: 'u',
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
      final banner = find.byType(PrebidAdMobBannerAd);
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

    testWidgets('a config change re-creates the view and its channel', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_admob/banner');
      addTearDown(views.dispose);
      final controller = PrebidBannerAdController();
      var loaded = 0;
      Widget banner(String configId) => _host(
        PrebidAdMobBannerAd(
          configId: configId,
          adMobAdUnitId: 'u',
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
        tester.getSize(find.byType(PrebidAdMobBannerAd)),
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

  group('PrebidAdMobNativeAd', () {
    testWidgets('default creation params', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_admob/native');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(const PrebidAdMobNativeAd(configId: 'c', adMobAdUnitId: 'u')),
      );
      await tester.pumpAndSettle();
      expect(views.creationParams, {'configId': 'c', 'adMobAdUnitId': 'u'});
    }, variant: android);

    testWidgets('sends assets and trackers', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_admob/native');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(
          const PrebidAdMobNativeAd(
            configId: 'c',
            adMobAdUnitId: 'u',
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

    testWidgets('every event reaches its callback; onAdSize resizes', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_admob/native');
      addTearDown(views.dispose);
      final fired = <String>[];
      await tester.pumpWidget(
        _host(
          PrebidAdMobNativeAd(
            configId: 'c',
            adMobAdUnitId: 'u',
            height: 120,
            listener: PrebidAdMobNativeAdListener(
              onAdLoaded: () => fired.add('loaded'),
              onAdImpression: () => fired.add('impression'),
              onAdClicked: () => fired.add('clicked'),
              onAdOpened: () => fired.add('opened'),
              onAdFailed: (e) => fired.add('failed:$e'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final native = find.byType(PrebidAdMobNativeAd);
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
        'onAdOpened',
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
        'opened',
        'failed:No fill',
        'failed:',
      ]);
    }, variant: android);

    for (final variant in [android, ios]) {
      testWidgets('a config change re-creates the view and its channel', (
        tester,
      ) async {
        final views = PlatformViewHarness('prebid_mobile_sdk_admob/native');
        addTearDown(views.dispose);
        final fired = <String>[];
        Widget native(String configId, {String? tag}) => _host(
          PrebidAdMobNativeAd(
            configId: configId,
            adMobAdUnitId: 'u',
            height: 100,
            listener: PrebidAdMobNativeAdListener(
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
        expect(tester.getSize(find.byType(PrebidAdMobNativeAd)).height, 100);

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
