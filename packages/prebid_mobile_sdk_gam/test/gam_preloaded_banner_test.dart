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
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  late ChannelHarness plugin;

  setUp(
    () => plugin = ChannelHarness('prebid_mobile_sdk_gam/preloaded_banner'),
  );

  int createdId() => plugin.argsOf('create')['channelId']! as int;

  test('load creates the banner on the plugin channel', () async {
    await PrebidGamPreloadedBannerAd(
      configId: 'c',
      gamAdUnitId: 'u',
      width: 320,
      height: 50,
      customTargeting: const {'k': 'v'},
      refreshIntervalSeconds: 30,
    ).load();
    final id = createdId();
    expect(plugin.argsOf('create'), {
      'channelId': id,
      'config': {
        'configId': 'c',
        'gamAdUnitId': 'u',
        'width': 320,
        'height': 50,
        'isVideo': false,
        'autoLoad': true,
        'refreshIntervalSeconds': 30,
        'customTargeting': {'k': 'v'},
        'channelId': id,
      },
    });
  });

  testWidgets('a view shows the banner; destroy ends it', (tester) async {
    final events = <String>[];
    final ad = PrebidGamPreloadedBannerAd(
      configId: 'c',
      gamAdUnitId: 'u',
      width: 320,
      height: 50,
      listener: PrebidBannerAdListener(onAdLoaded: () => events.add('loaded')),
    );
    // Real async: the plugin channel is static, so its futures outlive a
    // test's fake async zone.
    await tester.runAsync(ad.load);
    final id = createdId();
    final views = PlatformViewHarness('prebid_mobile_sdk_gam/banner');
    addTearDown(views.dispose);
    await tester.pumpWidget(_host(PrebidGamPreloadedBannerAdView(ad: ad)));
    // The view follows the creation future, completed in real async.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(views.channelIds.single, id);
    expect(views.creationParams, {'preloaded': true});

    final channel = 'prebid_mobile_sdk_gam/banner_$id';
    await PlatformViewHarness.emitOn(channel, 'onAdSize', {
      'width': 300.0,
      'height': 250.0,
    });
    await PlatformViewHarness.emitOn(channel, 'onAdLoaded');
    await tester.pump();
    expect(
      tester.getSize(find.byType(PrebidGamPreloadedBannerAdView)),
      const Size(300, 250),
    );
    expect(events, ['loaded']);

    await tester.runAsync(ad.load);
    await tester.runAsync(ad.stopRefresh);
    expect(views.calls.map((c) => c.method), ['loadAd', 'stopRefresh']);
    await tester.pumpWidget(_host(const SizedBox()));
    expect(plugin.calls.where((c) => c.method == 'destroy'), isEmpty);

    await tester.runAsync(ad.destroy);
    expect(plugin.argsOf('destroy'), {'channelId': id});
    expect(ad.size, const Size(320, 50));
  }, variant: ios);
}
