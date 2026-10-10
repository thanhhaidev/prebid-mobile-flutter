import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prebid_mobile_sdk_example/data/demo_items.dart';
import 'package:prebid_mobile_sdk_example/demo/demo_router.dart';
import 'package:prebid_mobile_sdk_example/demo/screens/special/instream_screen.dart';

void main() {
  test('every test case has a screen', () {
    for (final item in demoItems) {
      expect(() => buildDemoScreen(item), returnsNormally, reason: item.label);
    }
  });

  group('generateInstreamUriForGam (Prebid Util port)', () {
    test('builds the VAST ad tag with the keywords as cust_params', () {
      final uri = generateInstreamUriForGam(
        '/5300653/test_adunit_vast_pavliuchyk',
        const [Size(640, 480)],
        {'hb_pb': '0.50', 'hb_bidder': 'rubicon'},
      );
      expect(
        uri,
        'https://pubads.g.doubleclick.net/gampad/ads?sz=640x480'
        '&iu=/5300653/test_adunit_vast_pavliuchyk&impl=s&gdfp_req=1&env=vp'
        '&output=xml_vast4&unviewed_position_start=1'
        '&cust_params=hb_pb%3D0.50%26hb_bidder%3Drubicon%26',
      );
    });

    test('joins several sizes and omits cust_params without keywords', () {
      final uri = generateInstreamUriForGam('/1/x', const [
        Size(640, 480),
        Size(400, 300),
      ], null);
      expect(uri, contains('sz=640x480|400x300'));
      expect(uri, isNot(contains('cust_params')));
    });

    test('rejects unsupported sizes and empty input', () {
      expect(
        () => generateInstreamUriForGam('/1/x', const [Size(320, 50)], null),
        throwsArgumentError,
      );
      expect(
        () => generateInstreamUriForGam('', const [Size(640, 480)], null),
        throwsArgumentError,
      );
      expect(
        () => generateInstreamUriForGam('/1/x', const [], null),
        throwsArgumentError,
      );
    });
  });
}
