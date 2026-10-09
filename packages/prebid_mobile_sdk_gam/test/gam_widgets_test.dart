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

  testWidgets('banner: controller loads on demand; dispose detaches', (
    tester,
  ) async {
    final views = PlatformViewHarness('prebid_mobile_sdk_gam/banner');
    addTearDown(views.dispose);
    final controller = PrebidBannerAdController();
    var loaded = 0;

    await controller.loadAd();
    await tester.pumpWidget(
      _host(
        PrebidGamBannerAd(
          configId: 'config-b',
          gamAdUnitId: '/1/banner',
          width: 320,
          height: 50,
          autoLoad: false,
          controller: controller,
          listener: PrebidBannerAdListener(onAdLoaded: () => loaded++),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(views.calls.map((c) => c.method), ['loadAd']);
    await views.emit('onAdLoaded');
    expect(loaded, 1);

    await tester.pumpWidget(_host(const SizedBox()));
    await views.emit('onAdLoaded');
    expect(loaded, 1);
  }, variant: android);
}
