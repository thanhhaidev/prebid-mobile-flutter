import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import 'fake_platform_views.dart';
import 'mock_host_api.mocks.dart';

const _prefix = 'prebid_mobile_sdk/native_ad';
final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

Widget _host(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  late FakePlatformViews platform;
  late MockNativeAdHostApi api;

  setUp(() {
    platform = FakePlatformViews(channelPrefix: _prefix)..install();
    api = MockNativeAdHostApi();
    PrebidNativeAd.api = api;
  });

  tearDown(() => platform.uninstall());

  /// The id the ad sends to the native side (and the view's `adId` param).
  Future<int> adIdOf(PrebidNativeAd ad) async {
    await ad.loadAd();
    return verify(api.loadAd(captureAny, any)).captured.last as int;
  }

  Size viewSize(WidgetTester tester) =>
      tester.getSize(find.byType(PrebidNativeAdView));

  testWidgets('creates a view for the ad id', (tester) async {
    final ad = PrebidNativeAd(configId: 'n');
    final adId = await adIdOf(ad);

    await tester.pumpWidget(_host(Center(child: PrebidNativeAdView(ad: ad))));
    await tester.pump();

    final view = platform.views.single;
    expect(view.viewType, _prefix);
    expect(view.params, {'adId': adId});
  }, variant: _ios);

  testWidgets('creates an AndroidView on Android', (tester) async {
    final ad = PrebidNativeAd(configId: 'n');
    await tester.pumpWidget(_host(Center(child: PrebidNativeAdView(ad: ad))));
    await tester.pump();
    expect(find.byType(AndroidView), findsOneWidget);
    expect(platform.views, hasLength(1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('renders an empty box on other platforms', (tester) async {
    final ad = PrebidNativeAd(configId: 'n');
    await tester.pumpWidget(
      _host(Center(child: PrebidNativeAdView(ad: ad, width: 300))),
    );
    expect(platform.views, isEmpty);
    expect(viewSize(tester), const Size(300, 320));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  group('width', () {
    testWidgets('an explicit width is used', (tester) async {
      final ad = PrebidNativeAd(configId: 'n');
      await tester.pumpWidget(
        _host(
          Center(child: PrebidNativeAdView(ad: ad, width: 300, height: 200)),
        ),
      );
      expect(viewSize(tester), const Size(300, 200));
    }, variant: _ios);

    testWidgets('no width fills a bounded parent', (tester) async {
      final ad = PrebidNativeAd(configId: 'n');
      await tester.pumpWidget(
        _host(
          Center(
            child: SizedBox(width: 280, child: PrebidNativeAdView(ad: ad)),
          ),
        ),
      );
      expect(viewSize(tester), const Size(280, 320));
    }, variant: _ios);

    testWidgets('no width falls back to the screen width when unbounded', (
      tester,
    ) async {
      final ad = PrebidNativeAd(configId: 'n');
      await tester.pumpWidget(
        _host(
          ListView(
            scrollDirection: Axis.horizontal,
            children: [PrebidNativeAdView(ad: ad)],
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(viewSize(tester).width, screen.width);
      expect(platform.views, hasLength(1));
    }, variant: _ios);

    testWidgets('no width inside an UnconstrainedBox does not throw', (
      tester,
    ) async {
      final ad = PrebidNativeAd(configId: 'n');
      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.topLeft,
            child: UnconstrainedBox(child: PrebidNativeAdView(ad: ad)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }, variant: _ios);

    testWidgets('an explicit width is kept when unbounded', (tester) async {
      final ad = PrebidNativeAd(configId: 'n');
      await tester.pumpWidget(
        _host(
          ListView(
            scrollDirection: Axis.horizontal,
            children: [PrebidNativeAdView(ad: ad, width: 250)],
          ),
        ),
      );
      expect(viewSize(tester).width, 250);
    }, variant: _ios);
  });

  group('height', () {
    testWidgets('onAdSize grows the view to the rendered height', (
      tester,
    ) async {
      final ad = PrebidNativeAd(configId: 'n');
      await tester.pumpWidget(
        _host(Center(child: PrebidNativeAdView(ad: ad, width: 300))),
      );
      await tester.pump();

      await platform.send(platform.views.single, 'onAdSize', {'height': 410});
      await tester.pump();
      expect(viewSize(tester), const Size(300, 410));

      await platform.send(platform.views.single, 'onAdSize', {'height': 0});
      await platform.send(platform.views.single, 'onAdSize');
      await tester.pump();
      expect(viewSize(tester), const Size(300, 410));
    }, variant: _ios);

    testWidgets('onAdSize after unmount is ignored', (tester) async {
      final ad = PrebidNativeAd(configId: 'n');
      await tester.pumpWidget(_host(Center(child: PrebidNativeAdView(ad: ad))));
      await tester.pump();
      final view = platform.views.single;

      await tester.pumpWidget(_host(const SizedBox()));
      await platform.send(view, 'onAdSize', {'height': 100});
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(platform.disposed, [view.id]);
    }, variant: _ios);
  });

  group('keyed by ad id', () {
    testWidgets('rebuilding with the same ad keeps the view', (tester) async {
      final ad = PrebidNativeAd(configId: 'n');
      await tester.pumpWidget(
        _host(Center(child: PrebidNativeAdView(ad: ad, width: 300))),
      );
      await tester.pump();
      await tester.pumpWidget(
        _host(Center(child: PrebidNativeAdView(ad: ad, width: 310))),
      );
      await tester.pump();
      expect(platform.views, hasLength(1));
      expect(platform.disposed, isEmpty);
    }, variant: _ios);

    testWidgets('a different ad gets a new view at the initial height', (
      tester,
    ) async {
      final first = PrebidNativeAd(configId: 'a');
      final second = PrebidNativeAd(configId: 'b');
      final secondId = await adIdOf(second);

      await tester.pumpWidget(
        _host(Center(child: PrebidNativeAdView(ad: first, width: 300))),
      );
      await tester.pump();
      final oldView = platform.views.single;
      await platform.send(oldView, 'onAdSize', {'height': 500});
      await tester.pump();
      expect(viewSize(tester).height, 500);

      await tester.pumpWidget(
        _host(Center(child: PrebidNativeAdView(ad: second, width: 300))),
      );
      await tester.pump();

      expect(platform.views, hasLength(2));
      expect(platform.views.last.params, {'adId': secondId});
      expect(platform.disposed, [oldView.id]);
      expect(viewSize(tester).height, 320);

      // Late size reports from the old view are ignored.
      await platform.send(oldView, 'onAdSize', {'height': 999});
      await tester.pump();
      expect(viewSize(tester).height, 320);
    }, variant: _ios);
  });

  group('visible fraction', () {
    List<Object?> fractions(FakePlatformView view) => [
      for (final c in view.calls)
        if (c.method == 'setVisibleFraction') c.arguments,
    ];

    testWidgets('reports the on-screen fraction to the native view', (
      tester,
    ) async {
      final ad = PrebidNativeAd(configId: 'n');
      await tester.pumpWidget(
        _host(Center(child: PrebidNativeAdView(ad: ad, width: 300))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(fractions(platform.views.single), [1.0]);

      // Unchanged: nothing new is sent.
      await tester.pump(const Duration(milliseconds: 600));
      expect(fractions(platform.views.single), [1.0]);
    }, variant: _ios);

    testWidgets('a view clipped by a scroll viewport reports less', (
      tester,
    ) async {
      final ad = PrebidNativeAd(configId: 'n');
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 400,
              child: ListView(
                controller: controller,
                children: [
                  const SizedBox(height: 240),
                  PrebidNativeAdView(ad: ad),
                  const SizedBox(height: 800),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      // 240–560 in a 400 tall viewport: 160 of 320 visible.
      expect(fractions(platform.views.single), [0.5]);

      controller.jumpTo(240);
      await tester.pump(); // lay out the scrolled list first
      await tester.pump(const Duration(milliseconds: 300));
      expect(fractions(platform.views.single), [0.5, 1.0]);
    }, variant: _ios);

    testWidgets('stops reporting once disposed', (tester) async {
      final ad = PrebidNativeAd(configId: 'n');
      await tester.pumpWidget(
        _host(Center(child: PrebidNativeAdView(ad: ad, width: 300))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final view = platform.views.single;
      final sent = view.calls.length;

      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(view.calls.length, sent);
    }, variant: _ios);
  });
}
