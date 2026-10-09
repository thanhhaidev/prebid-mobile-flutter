import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_max/prebid_mobile_sdk_max.dart';

import 'channel_harness.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  testWidgets('banner: controller loads on demand; dispose detaches', (
    tester,
  ) async {
    final views = PlatformViewHarness('prebid_mobile_sdk_max/banner');
    addTearDown(views.dispose);
    final controller = PrebidBannerAdController();
    var loaded = 0;

    // Requested before the native view exists: runs once it is created.
    await controller.loadAd();
    await tester.pumpWidget(
      _host(
        PrebidMaxBannerAd(
          configId: 'config-b',
          maxAdUnitId: 'unit-b',
          width: 320,
          height: 50,
          autoLoad: false,
          controller: controller,
          listener: PrebidBannerAdListener(onAdLoaded: () => loaded++),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(views.viewChannel, isNotNull);
    expect(views.calls.map((c) => c.method), ['loadAd']);
    await controller.stopRefresh();
    expect(views.calls.last.method, 'stopRefresh');
    await views.emit('onAdLoaded');
    expect(loaded, 1);

    await tester.pumpWidget(_host(const SizedBox()));
    await views.emit('onAdLoaded'); // handler cleared: ignored
    expect(loaded, 1);
    await controller.loadAd(); // detached: queued, nothing sent
    expect(views.calls, hasLength(2));
  }, variant: android);

  testWidgets('native: dispose clears the event handler', (tester) async {
    final views = PlatformViewHarness('prebid_mobile_sdk_max/native');
    addTearDown(views.dispose);
    var loaded = 0;

    await tester.pumpWidget(
      _host(
        PrebidMaxNativeAd(
          configId: 'config-n',
          maxAdUnitId: 'unit-n',
          listener: PrebidMaxNativeAdListener(onAdLoaded: () => loaded++),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await views.emit('onAdLoaded');
    expect(loaded, 1);

    await tester.pumpWidget(_host(const SizedBox()));
    await views.emit('onAdLoaded');
    expect(loaded, 1);
  }, variant: android);
}
