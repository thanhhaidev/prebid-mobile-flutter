import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_gam/prebid_mobile_sdk_gam.dart';

import 'channel_harness.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  group('PrebidGamBannerAd', () {
    testWidgets('minimal creation params', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_gam/banner');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(
          const PrebidGamBannerAd(
            configId: 'c',
            gamAdUnitId: 'u',
            width: 320,
            height: 50,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(views.channelIds.single, isA<int>());
      expect(
        views.viewChannel,
        'prebid_mobile_sdk_gam/banner_${views.channelIds.single}',
      );
      expect(views.creationParams, {
        'configId': 'c',
        'gamAdUnitId': 'u',
        'width': 320,
        'height': 50,
        'isVideo': false,
        'autoLoad': true,
      });
    }, variant: android);

    testWidgets('optional creation params', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_gam/banner');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(
          const PrebidGamBannerAd(
            configId: 'c',
            gamAdUnitId: 'u',
            width: 320,
            height: 50,
            isVideo: true,
            autoLoad: false,
            refreshIntervalSeconds: 30,
            customTargeting: {'k': 'v'},
            videoPlacementType: VideoPlacementType.inFeed,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final p = views.creationParams!;
      expect(p['isVideo'], isTrue);
      expect(p['autoLoad'], isFalse);
      expect(p['refreshIntervalSeconds'], 30);
      expect(p['customTargeting'], {'k': 'v'});
      expect(p['videoPlacementType'], 'inFeed');
    }, variant: android);

    testWidgets('every event reaches its callback; onAdSize resizes', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_gam/banner');
      addTearDown(views.dispose);
      final fired = <String>[];
      await tester.pumpWidget(
        _host(
          PrebidGamBannerAd(
            configId: 'c',
            gamAdUnitId: 'u',
            width: 320,
            height: 50,
            listener: PrebidBannerAdListener(
              onAdLoaded: () => fired.add('loaded'),
              onAdDisplayed: () => fired.add('displayed'),
              onAdFailed: (e) => fired.add('failed:$e'),
              onAdClicked: () => fired.add('clicked'),
              onAdClosed: () => fired.add('closed'),
              onAdExpired: () => fired.add('expired'),
            ),
            videoListener: PrebidBannerVideoListener(
              onVideoCompleted: () => fired.add('v:completed'),
              onVideoPaused: () => fired.add('v:paused'),
              onVideoResumed: () => fired.add('v:resumed'),
              onVideoMuted: () => fired.add('v:muted'),
              onVideoUnmuted: () => fired.add('v:unmuted'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final banner = find.byType(PrebidGamBannerAd);
      expect(tester.getSize(banner), const Size(320, 50));

      await views.emit('onAdSize', {'width': 300.0, 'height': 250.0});
      await tester.pump();
      expect(tester.getSize(banner), const Size(300, 250));
      await views.emit('onAdSize', {'width': 0.0, 'height': 90.0}); // ignored
      await tester.pump();
      expect(tester.getSize(banner), const Size(300, 250));

      for (final e in [
        'onAdLoaded',
        'onAdDisplayed',
        'onAdClicked',
        'onAdClosed',
        'onAdExpired',
        'onVideoCompleted',
        'onVideoPaused',
        'onVideoResumed',
        'onVideoMuted',
        'onVideoUnmuted',
        'onUnknown',
      ]) {
        await views.emit(e);
      }
      await views.emit('onAdFailed', 'no fill');
      await views.emit('onAdFailed');
      expect(fired, [
        'loaded',
        'displayed',
        'clicked',
        'closed',
        'expired',
        'v:completed',
        'v:paused',
        'v:resumed',
        'v:muted',
        'v:unmuted',
        'failed:no fill',
        'failed:Unknown error',
      ]);
    }, variant: android);

    testWidgets('a config change re-creates the view and its channel', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_gam/banner');
      addTearDown(views.dispose);
      final controller = PrebidBannerAdController();
      var loaded = 0;
      Widget banner(String configId) => _host(
        PrebidGamBannerAd(
          configId: configId,
          gamAdUnitId: 'u',
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

      await tester.pumpWidget(banner('a')); // same config: same view
      await tester.pumpAndSettle();
      expect(views.viewChannels, hasLength(1));

      await tester.pumpWidget(banner('b'));
      await tester.pumpAndSettle();
      expect(views.viewChannels, hasLength(2));
      expect(views.disposedIds, hasLength(1));
      expect(views.createdParams.last?['configId'], 'b');
      // The new view starts at the requested size.
      expect(
        tester.getSize(find.byType(PrebidGamBannerAd)),
        const Size(320, 50),
      );

      await PlatformViewHarness.emitOn(first, 'onAdLoaded'); // old: ignored
      expect(loaded, 0);
      await views.emit('onAdLoaded');
      expect(loaded, 1);

      await controller.stopRefresh(); // attached to the new view
      expect(views.calls.last.method, 'stopRefresh');
    }, variant: android);
  });

  group('PrebidGamNativeAd', () {
    String channelOf(PlatformViewHarness views) =>
        'prebid_mobile_sdk_gam/native_${views.channelIds.last}';

    testWidgets('default creation params', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_gam/native');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(const PrebidGamNativeAd(configId: 'c', gamAdUnitId: 'u')),
      );
      await tester.pumpAndSettle();
      final p = views.creationParams!;
      expect(
        p.keys,
        unorderedEquals(['configId', 'gamAdUnitId', 'customFormatId']),
      );
      expect(views.channelIds.single, isA<int>());
      expect(p['configId'], 'c');
      expect(p['gamAdUnitId'], 'u');
      expect(p['customFormatId'], '');
    }, variant: android);

    testWidgets('sends format id, assets and trackers', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_gam/native');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(
          const PrebidGamNativeAd(
            configId: 'c',
            gamAdUnitId: 'u',
            customFormatId: '11934135',
            nativeParameters: NativeParameters(
              assets: [
                NativeAsset.title(length: 25, required: true),
                NativeAsset.data(dataType: NativeDataType.ctaText),
              ],
              eventTrackers: [
                NativeEventTracker(
                  eventType: NativeEventType.impression,
                  methods: [NativeEventTrackingMethod.image],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final p = views.creationParams!;
      expect(p['customFormatId'], '11934135');
      expect(p['assets'], [
        {'assetType': 'title', 'required': true, 'titleLength': 25},
        {'assetType': 'data', 'required': false, 'dataType': 12},
      ]);
      expect(p['eventTrackers'], [
        {
          'eventType': 1,
          'methods': [1],
        },
      ]);
    }, variant: android);

    testWidgets('sends targeting, GPID, ad slot and ORTB', (tester) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_gam/native');
      addTearDown(views.dispose);
      await tester.pumpWidget(
        _host(
          const PrebidGamNativeAd(
            configId: 'c',
            gamAdUnitId: 'u',
            customTargeting: {'section': 'news'},
            gpid: '/1111/home',
            pbAdSlot: '/1111/home-slot',
            impOrtbConfig: '{"ext":{"data":{"k":"v"}}}',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final p = views.creationParams!;
      expect(p['customTargeting'], {'section': 'news'});
      expect(p['gpid'], '/1111/home');
      expect(p['pbAdSlot'], '/1111/home-slot');
      expect(p['impOrtbConfig'], '{"ext":{"data":{"k":"v"}}}');
    }, variant: android);

    testWidgets('an event sent while the view is created is delivered', (
      tester,
    ) async {
      // The native side may fail (e.g. Prebid SDK not initialized) before
      // `onPlatformViewCreated`; the channel already listens by then.
      final views = PlatformViewHarness('prebid_mobile_sdk_gam/native');
      addTearDown(views.dispose);
      final fired = <String>[];
      await tester.pumpWidget(
        _host(
          PrebidGamNativeAd(
            configId: 'c',
            gamAdUnitId: 'u',
            listener: PrebidGamNativeAdListener(onFetchDemandFailed: fired.add),
          ),
        ),
      );
      final channel = channelOf(views);
      await PlatformViewHarness.emitOn(
        channel,
        'fetchDemandFailed',
        'prebidSdkNotInitialized',
      );
      expect(fired, ['prebidSdkNotInitialized']);
    }, variant: android);

    testWidgets('every event reaches its callback, with reasons', (
      tester,
    ) async {
      final views = PlatformViewHarness('prebid_mobile_sdk_gam/native');
      addTearDown(views.dispose);
      final fired = <String>[];
      await tester.pumpWidget(
        _host(
          PrebidGamNativeAd(
            configId: 'c',
            gamAdUnitId: 'u',
            width: 300,
            height: 100,
            listener: PrebidGamNativeAdListener(
              onFetchDemandSuccess: () => fired.add('fetchSuccess'),
              onFetchDemandFailed: (r) => fired.add('fetchFailed:$r'),
              onCustomAdLoaded: () => fired.add('custom'),
              onUnifiedAdLoaded: () => fired.add('unified'),
              onPrimaryAdFailed: (e) => fired.add('primaryFailed:$e'),
              onNativeAdLoaded: () => fired.add('native'),
              onPrimaryAdWinCustom: () => fired.add('winCustom'),
              onPrimaryAdWinUnified: () => fired.add('winUnified'),
              onAdImpression: () => fired.add('impression'),
              onAdClicked: () => fired.add('clicked'),
              onAdExpired: () => fired.add('expired'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final channel = channelOf(views);
      final native = find.byType(PrebidGamNativeAd);
      expect(tester.getSize(native), const Size(300, 100));

      await PlatformViewHarness.emitOn(channel, 'onAdSize', {'height': 240.0});
      await tester.pump();
      expect(tester.getSize(native), const Size(300, 240));

      await PlatformViewHarness.emitOn(channel, 'fetchDemandSuccess');
      await PlatformViewHarness.emitOn(
        channel,
        'fetchDemandFailed',
        'prebidDemandNoBids',
      );
      await PlatformViewHarness.emitOn(channel, 'fetchDemandFailed');
      for (final e in [
        'customAdLoaded',
        'unifiedAdLoaded',
        'nativeAdLoaded',
        'primaryAdWinCustom',
        'primaryAdWinUnified',
        'onAdImpression',
        'onAdClicked',
        'onAdExpired',
        'onUnknown',
      ]) {
        await PlatformViewHarness.emitOn(channel, e);
      }
      await PlatformViewHarness.emitOn(channel, 'primaryAdFailed', 'No fill');
      await PlatformViewHarness.emitOn(channel, 'primaryAdFailed');
      expect(fired, [
        'fetchSuccess',
        'fetchFailed:prebidDemandNoBids',
        'fetchFailed:prebidInvalidRequest',
        'custom',
        'unified',
        'native',
        'winCustom',
        'winUnified',
        'impression',
        'clicked',
        'expired',
        'primaryFailed:No fill',
        'primaryFailed:Unknown error',
      ]);
    }, variant: android);

    for (final variant in [android, ios]) {
      testWidgets('a config change re-creates the view on a new channel', (
        tester,
      ) async {
        final views = PlatformViewHarness('prebid_mobile_sdk_gam/native');
        addTearDown(views.dispose);
        final fired = <String>[];
        Widget native(String configId, {String? listenerTag}) => _host(
          PrebidGamNativeAd(
            configId: configId,
            gamAdUnitId: 'u',
            height: 100,
            listener: PrebidGamNativeAdListener(
              onNativeAdLoaded: () =>
                  fired.add('native:${listenerTag ?? configId}'),
            ),
          ),
        );

        await tester.pumpWidget(native('a'));
        await tester.pumpAndSettle();
        final first = channelOf(views);
        await PlatformViewHarness.emitOn(first, 'onAdSize', {'height': 300.0});
        await tester.pump();
        await PlatformViewHarness.emitOn(first, 'nativeAdLoaded');

        // A rebuild with the same config (new listener) keeps the view.
        await tester.pumpWidget(native('a', listenerTag: 'a2'));
        await tester.pumpAndSettle();
        expect(views.createdParams, hasLength(1));
        await PlatformViewHarness.emitOn(first, 'nativeAdLoaded');

        await tester.pumpWidget(native('b'));
        await tester.pumpAndSettle();
        expect(views.createdParams, hasLength(2));
        expect(views.disposedIds, hasLength(1));
        final second = channelOf(views);
        expect(second, isNot(first));
        expect(views.creationParams?['configId'], 'b');
        expect(tester.getSize(find.byType(PrebidGamNativeAd)).height, 100);

        await PlatformViewHarness.emitOn(first, 'nativeAdLoaded'); // ignored
        await PlatformViewHarness.emitOn(second, 'nativeAdLoaded');
        expect(fired, ['native:a', 'native:a2', 'native:b']);

        await tester.pumpWidget(_host(const SizedBox()));
        await PlatformViewHarness.emitOn(second, 'nativeAdLoaded');
        expect(fired, hasLength(3));
      }, variant: variant);
    }
  });
}
