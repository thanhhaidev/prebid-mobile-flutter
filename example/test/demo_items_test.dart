import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart' show PrebidAdFormat;
import 'package:prebid_mobile_sdk_example/data/demo_item.dart';
import 'package:prebid_mobile_sdk_example/data/demo_items.dart';

DemoItem byLabel(String label) =>
    demoItems.singleWhere((i) => i.label == label, orElse: () => fail(label));

void main() {
  test('registry has the 187 items of the original', () {
    expect(demoItems, hasLength(187));
  });

  test('labels are unique', () {
    final labels = demoItems.map((i) => i.label).toList();
    expect(labels.toSet(), hasLength(labels.length));
  });

  test('group sizes and order', () {
    int count(DemoIntegration i) =>
        demoItems.where((d) => d.integration == i).length;
    // SDK Testing adds 5 In-App and 1 GAM Original item.
    expect(count(DemoIntegration.original), 19 + 1);
    expect(count(DemoIntegration.inApp), 71 + 5);
    expect(count(DemoIntegration.gam), 38);
    expect(count(DemoIntegration.adMob), 27);
    expect(count(DemoIntegration.max), 26);

    expect(demoItems.first.label, 'Banner 320x50 (GAM Original) [OK, PUC]');
    expect(demoItems[19].label, 'Banner 320x50 (In-App)');
    expect(demoItems[90].label, 'Banner 320x50 (GAM) [OK, AppEvent]');
    expect(demoItems[128].label, 'Banner 320x50 (AdMob) [OK, OXB Adapter]');
    expect(demoItems[155].label, 'Banner 320x50 (MAX) [OK, Adapter]');
    expect(
      demoItems.last.label,
      'SDK Testing: Original API Banner Memory Leak',
    );
  });

  test('every item is remote', () {
    for (final item in demoItems) {
      expect(item.remote, isTrue, reason: item.label);
    }
  });

  test('spot checks', () {
    final viewability = byLabel(
      'MRAID 3.0: Viewability Compliance Ad (In-App)',
    );
    expect(viewability.size.width, 320);
    expect(viewability.size.height, 480);
    expect(viewability.screen, ScreenType.a1);

    final resizeErrors = byLabel('MRAID 2.0: Resize With Errors (In-App)');
    expect((resizeErrors.size.width, resizeErrors.size.height), (300, 100));

    final mraidVideo = byLabel('MRAID 2.0: Video Interstitial (In-App)');
    expect(mraidVideo.adFormats, {PrebidAdFormat.banner}); // title rule
    expect(mraidVideo.size.isMinSizePercentage, isTrue);

    final multiformat = byLabel('Multiformat Interstitial 320x480 (In-App)');
    expect(multiformat.screen, ScreenType.b1);
    expect(multiformat.randomConfigIds, [
      'prebid-demo-display-interstitial-320-480',
      'prebid-demo-video-interstitial-320-480',
    ]);
    expect(multiformat.adFormats, {
      PrebidAdFormat.banner,
      PrebidAdFormat.video,
    });

    final events = byLabel('Banner 320x50 Events (In-App)');
    expect(events.accountId, 'prebid-stored-request-enabled-events');

    final gamVideo = byLabel('Video Interstitial 320x480 (GAM) [OK, AppEvent]');
    expect(gamVideo.adUnitId, '/21808260008/prebid_oxb_interstitial_video');
    expect(gamVideo.category, DemoCategory.video);

    final custom = byLabel('Native Ad Custom Templates (GAM) [OK, NativeAd]');
    expect(custom.customFormatId, '11934135');
    expect(custom.screen, ScreenType.c2);

    final maxMrec = byLabel('Banner 300x250 (MAX) [OK, Adapter]');
    expect(maxMrec.adUnitId, '0b831dee5ef00774');

    final layout = byLabel('Banner 320x50 Layout (In-App)');
    expect(layout.configId, isNull);
    expect(layout.refreshSeconds, 5);

    expect(byLabel('Banner 320x50 Special Symbols (In-App)').appName, '天気');
    expect(
      byLabel(
        'Video Rewarded 320x480 With End Card And Ad Configuration(GAM) '
        '[OK, Metadata]',
      ).adUnitId,
      '/21808260008/prebid_oxb_rewarded_video_test',
    );
  });

  test('labels renamed / removed per gap analysis', () {
    final labels = demoItems.map((i) => i.label).toSet();
    for (final removed in [
      'MRAID 3.0: Viewability Compliance (In-App)',
      'Video Banner 300x250 (GAM Original) [OK, PUC]',
      'Video Interstitial 320x480 (GAM)',
      'Video Outstream with End Card (GAM)',
      'Banner 320x50 [Filter uncached bids] (GAM Original) [OK, PUC]',
    ]) {
      expect(labels, isNot(contains(removed)));
    }
  });

  test('configurator modes and labels follow the screen type', () {
    expect(
      byLabel('Banner 320x50 (In-App)').configuratorMode,
      ConfiguratorMode.banner,
    );
    expect(
      byLabel('Video Rewarded 320x480 (In-App)').configuratorMode,
      ConfiguratorMode.interstitial,
    );
    expect(byLabel('Native Ad (In-App)').configuratorMode, isNull);
    expect(
      byLabel('Video Outstream Feed (In-App)').configuratorMode,
      ConfiguratorMode.banner,
    );
    expect(byLabel('Native Ad Feed (In-App)').configuratorMode, isNull);
    expect(
      byLabel('Display Interstitial 320x480 (In-App)').showsAdUnitLabel,
      isFalse,
    );
    expect(
      byLabel(
        'SDK Testing: Rendering API Display Interstitial Memory Leak',
      ).showsAdUnitLabel,
      isTrue,
    );
  });
}
