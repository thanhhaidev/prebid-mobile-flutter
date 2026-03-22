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

  group('PrebidTargeting US Privacy / CCPA', () {
    test('setUSPrivacyString calls api', () async {
      await PrebidTargeting.setUSPrivacyString('1YNN');
      verify(mockApi.setUSPrivacyString('1YNN')).called(1);
    });

    test('setUSPrivacyString with null clears value', () async {
      await PrebidTargeting.setUSPrivacyString(null);
      verify(mockApi.setUSPrivacyString(null)).called(1);
    });

    test('getUSPrivacyString returns stored value', () async {
      when(mockApi.getUSPrivacyString()).thenAnswer((_) async => '1YNN');
      final result = await PrebidTargeting.getUSPrivacyString();
      expect(result, '1YNN');
    });

    test('getUSPrivacyString returns null when not set', () async {
      when(mockApi.getUSPrivacyString()).thenAnswer((_) async => null);
      final result = await PrebidTargeting.getUSPrivacyString();
      expect(result, isNull);
    });
  });

  group('PrebidTargeting User Ext Data', () {
    test('addUserExtData calls api with key and value', () async {
      await PrebidTargeting.addUserExtData(key: 'segment', value: 'premium');
      verify(mockApi.addUserExtData('segment', 'premium')).called(1);
    });

    test('updateUserExtData calls api with key and set of values', () async {
      await PrebidTargeting.updateUserExtData(
        key: 'interests',
        value: {'sports', 'tech'},
      );
      verify(mockApi.updateUserExtData('interests', any)).called(1);
    });

    test('removeUserExtData calls api', () async {
      await PrebidTargeting.removeUserExtData('segment');
      verify(mockApi.removeUserExtData('segment')).called(1);
    });

    test('clearUserExtData calls api', () async {
      await PrebidTargeting.clearUserExtData();
      verify(mockApi.clearUserExtData()).called(1);
    });
  });
}
