import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_flutter/prebid_mobile_flutter.dart';

import 'mock_host_api.mocks.dart';

void main() {
  late MockTargetingHostApi mockApi;

  setUp(() {
    mockApi = MockTargetingHostApi();
    PrebidTargeting.api = mockApi;
  });

  group('PrebidTargeting Privacy API', () {
    test('setSubjectToCOPPA calls api', () async {
      await PrebidTargeting.setSubjectToCOPPA(true);
      verify(mockApi.setSubjectToCOPPA(true)).called(1);
    });

    test('getSubjectToCOPPA calls api', () async {
      when(mockApi.getSubjectToCOPPA()).thenAnswer((_) async => true);
      final val = await PrebidTargeting.getSubjectToCOPPA();
      expect(val, isTrue);
    });

    test('setSubjectToGDPR calls api', () async {
      await PrebidTargeting.setSubjectToGDPR(false);
      verify(mockApi.setSubjectToGDPR(false)).called(1);
    });

    test('setGDPRConsentString calls api', () async {
      await PrebidTargeting.setGDPRConsentString('abc-123');
      verify(mockApi.setGDPRConsentString('abc-123')).called(1);
    });
  });

  group('PrebidTargeting Data API', () {
    test('addUserKeyword calls api', () async {
      await PrebidTargeting.addUserKeyword('sports');
      verify(mockApi.addUserKeyword('sports')).called(1);
    });

    test('addAppExtData calls api', () async {
      await PrebidTargeting.addAppExtData(key: 'userSegment', value: 'premium');
      verify(mockApi.addAppExtData('userSegment', 'premium')).called(1);
    });

    test('setGlobalOrtbConfig calls api', () async {
      await PrebidTargeting.setGlobalOrtbConfig('{"bcat": ["IAB1"]}');
      verify(mockApi.setGlobalOrtbConfig('{"bcat": ["IAB1"]}')).called(1);
    });

    test('setPublisherName calls api', () async {
      await PrebidTargeting.setPublisherName('CoolApp');
      verify(mockApi.setPublisherName('CoolApp')).called(1);
    });
  });
}
