import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import 'fake_platform_views.dart';
import 'mock_host_api.mocks.dart';

const _prefix = 'prebid_mobile_sdk/banner_ad';
final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockBannerAdHostApi api;
  late FakePlatformViews platform;

  setUp(() {
    api = MockBannerAdHostApi();
    PrebidPreloadedBannerAd.api = api;
    platform = FakePlatformViews(channelPrefix: _prefix)..install();
  });

  tearDown(() => platform.uninstall());

  /// The channel id the banner was created with.
  int createdId() => verify(api.create(captureAny, any)).captured.single as int;

  /// Records the calls Dart makes on the banner's channel.
  List<MethodCall> recordCalls(int id) {
    final calls = <MethodCall>[];
    _messenger.setMockMethodCallHandler(MethodChannel('${_prefix}_$id'), (
      c,
    ) async {
      calls.add(c);
      return null;
    });
    return calls;
  }

  /// Delivers a native event on the banner's channel.
  Future<void> send(int id, String method, [Object? args]) =>
      _messenger.handlePlatformMessage(
        '${_prefix}_$id',
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );

  group('PrebidPreloadedBannerAd', () {
    test('load creates the native banner with its configuration', () async {
      await PrebidPreloadedBannerAd(
        configId: 'cfg',
        width: 320,
        height: 50,
        additionalSizes: const [Size(300, 250)],
        adFormats: const {PrebidAdFormat.banner},
        pbAdSlot: '/slot',
        gpid: '/1/home',
        adPosition: PrebidAdPosition.header,
        globalOrtbConfig: '{"app":{}}',
        refreshIntervalSeconds: 30,
      ).load();

      final config =
          verify(api.create(any, captureAny)).captured.single
              as Map<String?, Object?>;
      expect(config, {
        'configId': 'cfg',
        'width': 320,
        'height': 50,
        'isVideo': false,
        'autoLoad': true,
        'additionalSizes': [300, 250],
        'refreshIntervalSeconds': 30,
        'adFormats': ['banner'],
        'pbAdSlot': '/slot',
        'adPosition': 4,
        'impOrtbConfig': '{"ext":{"gpid":"/1/home"}}',
        'globalOrtbConfig': '{"app":{}}',
      });
    });

    test('a second load reloads the same banner', () async {
      final ad = PrebidPreloadedBannerAd(configId: 'c', width: 1, height: 1);
      await ad.load();
      final calls = recordCalls(createdId());
      await ad.load();
      await ad.stopRefresh();
      verifyNever(api.create(any, any));
      expect(calls.map((c) => c.method), ['loadAd', 'stopRefresh']);
    });

    test('events reach the listener, the bid and the size', () async {
      final events = <String>[];
      final ad = PrebidPreloadedBannerAd(
        configId: 'c',
        width: 320,
        height: 50,
        listener: PrebidBannerAdListener(
          onAdLoaded: () => events.add('loaded'),
          onAdFailed: (e) => events.add('failed: $e'),
        ),
        videoListener: PrebidBannerVideoListener(
          onVideoCompleted: () => events.add('completed'),
        ),
      );
      expect(ad.size, const Size(320, 50));
      await ad.load();
      final id = createdId();

      await send(id, 'onAdSize', {'width': 300.0, 'height': 250.0});
      await send(id, 'onAdSize', {'width': 300.0, 'height': 0.0});
      await send(id, 'onAdLoaded', {'price': 1.5, 'width': 300, 'height': 250});
      expect(ad.winningBid?.price, 1.5);
      expect(ad.winningBid?.size, const Size(300, 250));
      // A refresh without a bid leaves no winning bid.
      await send(id, 'onAdFailed', {'error': 'no bid'});
      expect(ad.winningBid, isNull);
      await send(id, 'onVideoCompleted');

      expect(ad.size, const Size(300, 250));
      expect(events, ['loaded', 'failed: no bid', 'completed']);
    });

    test('destroy ends the native banner; load starts afresh', () async {
      final ad = PrebidPreloadedBannerAd(configId: 'c', width: 320, height: 50);
      await ad.load();
      final first = createdId();
      await send(first, 'onAdSize', {'width': 300.0, 'height': 250.0});
      await send(first, 'onAdLoaded', {'price': 1.5});
      await ad.destroy();
      await ad.destroy();
      verify(api.destroy(first)).called(1);
      expect((ad.size, ad.winningBid), (const Size(320, 50), null));

      await ad.load();
      final second = createdId();
      expect(second, isNot(first));
    });

    test('destroy before load has nothing to destroy', () async {
      final ad = PrebidPreloadedBannerAd(configId: 'c', width: 1, height: 1);
      await ad.destroy();
      await ad.stopRefresh();
      verifyZeroInteractions(api);
    });

    test('a banner that failed to be created is not destroyed', () async {
      // Pigeon reports a platform failure as a failed Future.
      when(
        api.create(any, any),
      ).thenAnswer((_) async => throw PlatformException(code: 'x'));
      final ad = PrebidPreloadedBannerAd(configId: 'c', width: 1, height: 1);
      await expectLater(ad.load(), throwsA(isA<PlatformException>()));
      await ad.destroy();
      verifyNever(api.destroy(any));
    });

    test('the next load retries a failed creation', () async {
      var fail = true;
      when(api.create(any, any)).thenAnswer((_) async {
        if (fail) throw PlatformException(code: 'x');
      });
      final ad = PrebidPreloadedBannerAd(configId: 'c', width: 1, height: 1);
      await expectLater(ad.load(), throwsA(isA<PlatformException>()));
      await ad.stopRefresh(); // Nothing to stop.
      fail = false;
      await ad.load();
      final ids = verify(api.create(captureAny, any)).captured;
      expect(ids, hasLength(2));
      expect(ids.first, isNot(ids.last));
    });
  });

  group('PrebidPreloadedBannerAdView', () {
    testWidgets('shows the loaded banner at its size', (tester) async {
      final ad = PrebidPreloadedBannerAd(configId: 'c', width: 320, height: 50);
      await ad.load();
      final id = createdId();
      await tester.pumpWidget(_host(PrebidPreloadedBannerAdView(ad: ad)));
      await tester.pump();

      final view = platform.views.single;
      expect(view.viewType, _prefix);
      expect(view.channelId, id);
      expect(view.params, {'preloaded': true});
      final slot = find.byType(PrebidPreloadedBannerAdView);
      expect(tester.getSize(slot), const Size(320, 50));

      await send(id, 'onAdSize', {'width': 300.0, 'height': 250.0});
      await tester.pump();
      expect(tester.getSize(slot), const Size(300, 250));
    }, variant: _ios);

    testWidgets('removing the view keeps the banner', (tester) async {
      final ad = PrebidPreloadedBannerAd(configId: 'c', width: 320, height: 50);
      await ad.load();
      await tester.pumpWidget(_host(PrebidPreloadedBannerAdView(ad: ad)));
      await tester.pump();
      await tester.pumpWidget(_host(const SizedBox()));

      expect(platform.disposed, [platform.views.single.id]);
      verifyNever(api.destroy(any));
    }, variant: _ios);

    testWidgets('a destroyed banner leaves the slot empty until reloaded', (
      tester,
    ) async {
      final ad = PrebidPreloadedBannerAd(configId: 'c', width: 320, height: 50);
      await ad.load();
      await tester.pumpWidget(_host(PrebidPreloadedBannerAdView(ad: ad)));
      await tester.pump();
      await ad.destroy();
      await tester.pump();
      expect(platform.live, isEmpty);
      expect(
        tester.getSize(find.byType(PrebidPreloadedBannerAdView)),
        const Size(320, 50),
      );

      await ad.load();
      await tester.pump();
      await tester.pump();
      final ids = verify(api.create(captureAny, any)).captured;
      expect(platform.live.single.channelId, ids.last);
    }, variant: _ios);

    testWidgets('shows nothing when the banner could not be created', (
      tester,
    ) async {
      when(
        api.create(any, any),
      ).thenAnswer((_) async => throw PlatformException(code: 'x'));
      final ad = PrebidPreloadedBannerAd(configId: 'c', width: 320, height: 50);
      await expectLater(ad.load(), throwsA(isA<PlatformException>()));
      await tester.pumpWidget(_host(PrebidPreloadedBannerAdView(ad: ad)));
      await tester.pump();
      expect(platform.views, isEmpty);
    }, variant: _ios);

    testWidgets('a new ad gets its own view', (tester) async {
      final first = PrebidPreloadedBannerAd(configId: 'a', width: 1, height: 1);
      final second = PrebidPreloadedBannerAd(
        configId: 'b',
        width: 1,
        height: 1,
      );
      await first.load();
      await second.load();
      await tester.pumpWidget(_host(PrebidPreloadedBannerAdView(ad: first)));
      await tester.pump();
      await tester.pumpWidget(_host(PrebidPreloadedBannerAdView(ad: second)));
      await tester.pump();

      final ids = verify(api.create(captureAny, any)).captured;
      expect(platform.views.map((v) => v.channelId), ids);
      expect(platform.disposed, [platform.views.first.id]);
    }, variant: _ios);

    testWidgets('a view built before load shows the banner once loaded', (
      tester,
    ) async {
      final ad = PrebidPreloadedBannerAd(configId: 'c', width: 320, height: 50);
      await tester.pumpWidget(_host(PrebidPreloadedBannerAdView(ad: ad)));
      await tester.pump();
      expect(platform.views, isEmpty);

      await ad.load();
      await tester.pump();
      await tester.pump();
      expect(platform.views.single.channelId, createdId());
    }, variant: _ios);
  });
}
