import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk_admob/prebid_mobile_sdk_admob.dart';

import 'channel_harness.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  late ChannelHarness plugin;

  setUp(
    () => plugin = ChannelHarness('prebid_mobile_sdk_admob/preloaded_banner'),
  );

  int createdId() => plugin.argsOf('create')['channelId']! as int;

  test('load creates the banner on the plugin channel', () async {
    await PrebidAdMobPreloadedBannerAd(
      configId: 'c',
      adMobAdUnitId: 'u',
      width: 320,
      height: 50,
      adaptive: true,
      refreshIntervalSeconds: 30,
    ).load();
    final id = createdId();
    expect(plugin.argsOf('create'), {
      'channelId': id,
      'config': {
        'configId': 'c',
        'adMobAdUnitId': 'u',
        'width': 320,
        'height': 50,
        'autoLoad': true,
        'adaptive': true,
        'refreshIntervalSeconds': 30,
        'adaptiveWidth': 320,
        'channelId': id,
      },
    });
  });

  testWidgets('a view shows the banner; destroy ends it', (tester) async {
    final events = <String>[];
    final ad = PrebidAdMobPreloadedBannerAd(
      configId: 'c',
      adMobAdUnitId: 'u',
      width: 320,
      height: 50,
      listener: PrebidBannerAdListener(onAdLoaded: () => events.add('loaded')),
    );
    // Real async: the plugin channel is static, so its futures outlive a
    // test's fake async zone.
    await tester.runAsync(ad.load);
    final id = createdId();
    final views = PlatformViewHarness('prebid_mobile_sdk_admob/banner');
    addTearDown(views.dispose);
    await tester.pumpWidget(_host(PrebidAdMobPreloadedBannerAdView(ad: ad)));
    // The view follows the creation future, completed in real async.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(views.channelIds.single, id);
    expect(views.creationParams, {'preloaded': true});

    final channel = 'prebid_mobile_sdk_admob/banner_$id';
    await PlatformViewHarness.emitOn(channel, 'onAdSize', {
      'width': 300.0,
      'height': 250.0,
    });
    await PlatformViewHarness.emitOn(channel, 'onAdLoaded');
    await tester.pump();
    expect(
      tester.getSize(find.byType(PrebidAdMobPreloadedBannerAdView)),
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
