import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import 'fake_platform_views.dart';

const _prefix = 'prebid_mobile_sdk/banner_ad';
final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

void main() {
  late FakePlatformViews platform;

  setUp(() {
    platform = FakePlatformViews(channelPrefix: _prefix)..install();
  });

  tearDown(() => platform.uninstall());

  Size slot(WidgetTester tester) => tester.getSize(find.byType(PrebidBannerAd));

  group('PrebidBannerAd platform view', () {
    testWidgets('creates a UiKitView with every creation param', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const PrebidBannerAd(
            configId: 'cfg',
            width: 320,
            height: 50,
            additionalSizes: [Size(300, 250)],
            adFormats: {PrebidAdFormat.banner, PrebidAdFormat.video},
            pbAdSlot: '/slot',
            adPosition: PrebidAdPosition.header,
            videoParameters: VideoParameters(mimes: ['video/mp4']),
            impOrtbConfig: '{"ext":{}}',
            autoLoad: false,
            refreshIntervalSeconds: 30,
            videoPlacementType: VideoPlacementType.inFeed,
          ),
        ),
      );
      await tester.pump();

      final view = platform.views.single;
      expect(view.viewType, _prefix);
      expect(view.params, {
        'configId': 'cfg',
        'width': 320,
        'height': 50,
        'isVideo': false,
        'autoLoad': false,
        'additionalSizes': [300, 250],
        'refreshIntervalSeconds': 30,
        'adFormats': ['banner', 'video'],
        'pbAdSlot': '/slot',
        'adPosition': 4,
        'videoParameters': {
          'mimes': ['video/mp4'],
        },
        'impOrtbConfig': '{"ext":{}}',
        'videoPlacementType': 'inFeed',
      });
      expect(slot(tester), const Size(320, 50));
    }, variant: _ios);

    testWidgets('omits unset optional params', (tester) async {
      await tester.pumpWidget(
        _host(const PrebidBannerAd(configId: 'c', width: 300, height: 250)),
      );
      await tester.pump();
      expect(platform.views.single.params, {
        'configId': 'c',
        'width': 300,
        'height': 250,
        'isVideo': false,
        'autoLoad': true,
      });
    }, variant: _ios);

    testWidgets('creates an AndroidView on Android', (tester) async {
      await tester.pumpWidget(
        _host(const PrebidBannerAd(configId: 'and', width: 320, height: 50)),
      );
      await tester.pump();
      expect(find.byType(AndroidView), findsOneWidget);
      expect(platform.views.single.params?['configId'], 'and');
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('renders an empty slot on other platforms', (tester) async {
      await tester.pumpWidget(
        _host(const PrebidBannerAd(configId: 'x', width: 320, height: 50)),
      );
      expect(find.byType(UiKitView), findsNothing);
      expect(find.byType(AndroidView), findsNothing);
      expect(platform.views, isEmpty);
      expect(slot(tester), const Size(320, 50));
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  group('PrebidBannerAd onAdSize', () {
    testWidgets('resizes the slot to the rendered creative', (tester) async {
      await tester.pumpWidget(
        _host(const PrebidBannerAd(configId: 'c', width: 320, height: 50)),
      );
      await tester.pump();

      await platform.send(platform.views.single, 'onAdSize', {
        'width': 300,
        'height': 250.0,
      });
      await tester.pump();
      expect(slot(tester), const Size(300, 250));
    }, variant: _ios);

    testWidgets('ignores missing or non-positive sizes', (tester) async {
      await tester.pumpWidget(
        _host(const PrebidBannerAd(configId: 'c', width: 320, height: 50)),
      );
      await tester.pump();
      final view = platform.views.single;

      await platform.send(view, 'onAdSize', {'width': 0, 'height': 250});
      await platform.send(view, 'onAdSize', {'width': 300, 'height': -1});
      await platform.send(view, 'onAdSize', {'width': 300});
      await platform.send(view, 'onAdSize');
      await tester.pump();
      expect(slot(tester), const Size(320, 50));
    }, variant: _ios);

    testWidgets('after unmount is ignored without errors', (tester) async {
      await tester.pumpWidget(
        _host(const PrebidBannerAd(configId: 'c', width: 320, height: 50)),
      );
      await tester.pump();
      final view = platform.views.single;

      await tester.pumpWidget(_host(const SizedBox()));
      await platform.send(view, 'onAdSize', {'width': 300, 'height': 250});
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(platform.disposed, [view.id]);
    }, variant: _ios);
  });

  group('PrebidBannerAd listeners', () {
    testWidgets('maps every banner and video event', (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        _host(
          PrebidBannerAd(
            configId: 'c',
            width: 320,
            height: 50,
            listener: PrebidBannerAdListener(
              onAdLoaded: () => events.add('loaded'),
              onAdDisplayed: () => events.add('displayed'),
              onAdFailed: (e) => events.add('failed:$e'),
              onAdClicked: () => events.add('clicked'),
              onAdClosed: () => events.add('closed'),
              onAdExpired: () => events.add('expired'),
            ),
            videoListener: PrebidBannerVideoListener(
              onVideoCompleted: () => events.add('videoCompleted'),
              onVideoPaused: () => events.add('videoPaused'),
              onVideoResumed: () => events.add('videoResumed'),
              onVideoMuted: () => events.add('videoMuted'),
              onVideoUnmuted: () => events.add('videoUnmuted'),
            ),
          ),
        ),
      );
      await tester.pump();
      final view = platform.views.single;

      await platform.send(view, 'onAdLoaded');
      await platform.send(view, 'onAdDisplayed');
      await platform.send(view, 'onAdFailed', 'no fill');
      await platform.send(view, 'onAdFailed');
      await platform.send(view, 'onAdClicked');
      await platform.send(view, 'onAdClosed');
      await platform.send(view, 'onAdExpired');
      await platform.send(view, 'onVideoCompleted');
      await platform.send(view, 'onVideoPaused');
      await platform.send(view, 'onVideoResumed');
      await platform.send(view, 'onVideoMuted');
      await platform.send(view, 'onVideoUnmuted');
      await platform.send(view, 'onSomethingElse');

      expect(events, [
        'loaded',
        'displayed',
        'failed:no fill',
        'failed:',
        'clicked',
        'closed',
        'expired',
        'videoCompleted',
        'videoPaused',
        'videoResumed',
        'videoMuted',
        'videoUnmuted',
      ]);
    }, variant: _ios);

    testWidgets('uses the current widget listener', (tester) async {
      final events = <String>[];
      Widget banner(String tag) => _host(
        PrebidBannerAd(
          configId: 'c',
          width: 320,
          height: 50,
          listener: PrebidBannerAdListener(onAdLoaded: () => events.add(tag)),
        ),
      );
      await tester.pumpWidget(banner('first'));
      await tester.pump();
      await tester.pumpWidget(banner('second'));

      await platform.send(platform.views.single, 'onAdLoaded');
      expect(events, ['second']);
    }, variant: _ios);

    testWidgets('works without listeners', (tester) async {
      await tester.pumpWidget(
        _host(const PrebidBannerAd(configId: 'c', width: 320, height: 50)),
      );
      await tester.pump();
      for (final e in ['onAdLoaded', 'onAdFailed', 'onVideoPaused']) {
        await platform.send(platform.views.single, e);
      }
      expect(tester.takeException(), isNull);
    }, variant: _ios);
  });

  group('PrebidBannerAd config changes', () {
    testWidgets('a changed config re-keys the view at the requested size', (
      tester,
    ) async {
      final events = <String>[];
      Widget banner(String configId, int height) => _host(
        PrebidBannerAd(
          configId: configId,
          width: 320,
          height: height,
          listener: PrebidBannerAdListener(
            onAdLoaded: () => events.add(configId),
          ),
        ),
      );
      await tester.pumpWidget(banner('a', 50));
      await tester.pump();
      final first = platform.views.single;
      await platform.send(first, 'onAdSize', {'width': 300, 'height': 250});
      await tester.pump();
      expect(slot(tester), const Size(300, 250));

      await tester.pumpWidget(banner('b', 100));
      await tester.pump();

      expect(platform.views, hasLength(2));
      final second = platform.views.last;
      expect(second.params?['configId'], 'b');
      expect(platform.disposed, [first.id]);
      expect(slot(tester), const Size(320, 100));

      // The old view's channel is no longer listened to.
      await platform.send(first, 'onAdLoaded');
      await platform.send(first, 'onAdSize', {'width': 10, 'height': 10});
      await platform.send(second, 'onAdLoaded');
      await tester.pump();
      expect(events, ['b']);
      expect(slot(tester), const Size(320, 100));
    }, variant: _ios);

    testWidgets('an unchanged config keeps the view', (tester) async {
      await tester.pumpWidget(
        _host(const PrebidBannerAd(configId: 'a', width: 320, height: 50)),
      );
      await tester.pump();
      await tester.pumpWidget(
        _host(
          const PrebidBannerAd(
            configId: 'a',
            width: 320,
            height: 50,
            listener: PrebidBannerAdListener(),
          ),
        ),
      );
      await tester.pump();
      expect(platform.views, hasLength(1));
      expect(platform.disposed, isEmpty);
    }, variant: _ios);

    testWidgets('controller.loadAd() during a config change is replayed on '
        'the new view', (tester) async {
      final controller = PrebidBannerAdController();
      Widget banner(String configId) => _host(
        PrebidBannerAd(
          configId: configId,
          width: 320,
          height: 50,
          autoLoad: false,
          controller: controller,
        ),
      );
      await tester.pumpWidget(banner('a'));
      await tester.pump();
      final first = platform.views.single;

      platform.createGate = Completer<void>();
      await tester.pumpWidget(banner('b'));
      // The new view isn't created yet: the load must wait for it rather
      // than reach the disposed view.
      await controller.loadAd();
      expect(first.calls, isEmpty);

      platform.createGate!.complete();
      await tester.pump();
      await tester.pump();
      final second = platform.views.last;
      expect(second.params?['configId'], 'b');
      expect(second.calls.map((c) => c.method), ['loadAd']);
      expect(first.calls, isEmpty);
    }, variant: _ios);

    testWidgets('a queued load is dropped when the new view auto-loads', (
      tester,
    ) async {
      final controller = PrebidBannerAdController();
      Widget banner(String configId) => _host(
        PrebidBannerAd(
          configId: configId,
          width: 320,
          height: 50,
          controller: controller,
        ),
      );
      await tester.pumpWidget(banner('a'));
      await tester.pump();

      platform.createGate = Completer<void>();
      await tester.pumpWidget(banner('b'));
      await controller.loadAd();
      platform.createGate!.complete();
      await tester.pump();
      await tester.pump();

      for (final v in platform.views) {
        expect(v.calls, isEmpty);
      }
    }, variant: _ios);

    testWidgets('a config change with a swapped controller attaches the new '
        'controller to the new view only', (tester) async {
      final a = PrebidBannerAdController();
      final b = PrebidBannerAdController();
      await tester.pumpWidget(
        _host(
          PrebidBannerAd(
            configId: 'a',
            width: 320,
            height: 50,
            autoLoad: false,
            controller: a,
          ),
        ),
      );
      await tester.pump();
      final first = platform.views.single;

      await tester.pumpWidget(
        _host(
          PrebidBannerAd(
            configId: 'b',
            width: 320,
            height: 50,
            autoLoad: false,
            controller: b,
          ),
        ),
      );
      await tester.pump();
      final second = platform.views.last;

      await a.loadAd();
      await b.loadAd();
      await b.stopRefresh();
      expect(first.calls, isEmpty);
      expect(second.calls.map((c) => c.method), ['loadAd', 'stopRefresh']);
    }, variant: _ios);
  });

  group('PrebidBannerAd controller', () {
    testWidgets('loadAd and stopRefresh reach the view', (tester) async {
      final controller = PrebidBannerAdController();
      await tester.pumpWidget(
        _host(
          PrebidBannerAd(
            configId: 'c',
            width: 320,
            height: 50,
            autoLoad: false,
            controller: controller,
          ),
        ),
      );
      await tester.pump();

      await controller.loadAd();
      await controller.stopRefresh();
      expect(platform.views.single.calls.map((c) => c.method), [
        'loadAd',
        'stopRefresh',
      ]);
    }, variant: _ios);

    testWidgets('a load requested before the view exists runs on creation', (
      tester,
    ) async {
      final controller = PrebidBannerAdController();
      await controller.loadAd();
      await tester.pumpWidget(
        _host(
          PrebidBannerAd(
            configId: 'c',
            width: 320,
            height: 50,
            autoLoad: false,
            controller: controller,
          ),
        ),
      );
      await tester.pump();
      expect(platform.views.single.calls.map((c) => c.method), ['loadAd']);
    }, variant: _ios);

    testWidgets('swapping the controller moves the view to the new one', (
      tester,
    ) async {
      final a = PrebidBannerAdController();
      final b = PrebidBannerAdController();
      Widget banner(PrebidBannerAdController c) => _host(
        PrebidBannerAd(
          configId: 'c',
          width: 320,
          height: 50,
          autoLoad: false,
          controller: c,
        ),
      );
      await tester.pumpWidget(banner(a));
      await tester.pump();
      await tester.pumpWidget(banner(b));
      await tester.pump();

      final view = platform.views.single;
      await a.loadAd(); // detached: queued, not sent
      await a.stopRefresh();
      expect(view.calls, isEmpty);

      await b.loadAd();
      expect(view.calls.map((c) => c.method), ['loadAd']);
    }, variant: _ios);

    testWidgets('dispose detaches the controller', (tester) async {
      final controller = PrebidBannerAdController();
      await tester.pumpWidget(
        _host(
          PrebidBannerAd(
            configId: 'c',
            width: 320,
            height: 50,
            autoLoad: false,
            controller: controller,
          ),
        ),
      );
      await tester.pump();
      final view = platform.views.single;

      await tester.pumpWidget(_host(const SizedBox()));
      await controller.loadAd();
      await controller.stopRefresh();
      expect(view.calls, isEmpty);
      expect(platform.disposed, [view.id]);
    }, variant: _ios);
  });
}
