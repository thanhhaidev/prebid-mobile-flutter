import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

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

  group('PrebidTargeting OMID and location', () {
    test('OMID partner name / version call api', () async {
      await PrebidTargeting.setOmidPartnerName('Prebid');
      await PrebidTargeting.setOmidPartnerVersion('1.0');
      verify(mockApi.setOmidPartnerName('Prebid')).called(1);
      verify(mockApi.setOmidPartnerVersion('1.0')).called(1);
    });

    test('user location and precision call api', () async {
      await PrebidTargeting.setUserLatLng(10.5, 106.7);
      await PrebidTargeting.setLocationPrecision(2);
      verify(mockApi.setUserLatLng(10.5, 106.7)).called(1);
      verify(mockApi.setLocationPrecision(2)).called(1);
    });
  });

  group('PrebidTargeting getters', () {
    test('privacy getters return the api values', () async {
      when(mockApi.getSubjectToGDPR()).thenAnswer((_) async => true);
      when(mockApi.getGDPRConsentString()).thenAnswer((_) async => 'tcf');
      when(mockApi.getPurposeConsents()).thenAnswer((_) async => '101');
      when(mockApi.getDeviceAccessConsent()).thenAnswer((_) async => false);
      when(mockApi.getSubjectToCOPPA()).thenAnswer((_) async => null);

      expect(await PrebidTargeting.getSubjectToGDPR(), isTrue);
      expect(await PrebidTargeting.getGDPRConsentString(), 'tcf');
      expect(await PrebidTargeting.getPurposeConsents(), '101');
      expect(await PrebidTargeting.getDeviceAccessConsent(), isFalse);
      expect(await PrebidTargeting.getSubjectToCOPPA(), isNull);
    });

    test('purpose consents setter and null clears', () async {
      await PrebidTargeting.setPurposeConsents('11');
      await PrebidTargeting.setPurposeConsents(null);
      await PrebidTargeting.setSubjectToGDPR(null);
      await PrebidTargeting.setGDPRConsentString(null);
      verify(mockApi.setPurposeConsents('11')).called(1);
      verify(mockApi.setPurposeConsents(null)).called(1);
      verify(mockApi.setSubjectToGDPR(null)).called(1);
      verify(mockApi.setGDPRConsentString(null)).called(1);
    });

    test('getGlobalOrtbConfig returns the api value', () async {
      when(mockApi.getGlobalOrtbConfig()).thenAnswer((_) async => '{}');
      expect(await PrebidTargeting.getGlobalOrtbConfig(), '{}');
      await PrebidTargeting.setGlobalOrtbConfig(null);
      verify(mockApi.setGlobalOrtbConfig(null)).called(1);
    });
  });

  group('PrebidTargeting keywords', () {
    test('user keywords call api', () async {
      when(mockApi.getUserKeywords()).thenAnswer((_) async => ['a', 'b']);
      await PrebidTargeting.addUserKeywords({'a', 'b'});
      await PrebidTargeting.removeUserKeyword('a');
      await PrebidTargeting.clearUserKeywords();
      verify(mockApi.addUserKeywords(['a', 'b'])).called(1);
      verify(mockApi.removeUserKeyword('a')).called(1);
      verify(mockApi.clearUserKeywords()).called(1);
      expect(await PrebidTargeting.getUserKeywords(), ['a', 'b']);
    });

    test('app keywords call api', () async {
      await PrebidTargeting.addAppKeyword('news');
      await PrebidTargeting.addAppKeywords({'x', 'y'});
      await PrebidTargeting.removeAppKeyword('x');
      await PrebidTargeting.clearAppKeywords();
      verify(mockApi.addAppKeyword('news')).called(1);
      verify(mockApi.addAppKeywords(['x', 'y'])).called(1);
      verify(mockApi.removeAppKeyword('x')).called(1);
      verify(mockApi.clearAppKeywords()).called(1);
    });
  });

  group('PrebidTargeting app ext data and access control', () {
    test('app ext data calls api', () async {
      await PrebidTargeting.updateAppExtData(key: 'k', value: {'v1', 'v2'});
      await PrebidTargeting.removeAppExtData('k');
      await PrebidTargeting.clearAppExtData();
      verify(mockApi.updateAppExtData('k', ['v1', 'v2'])).called(1);
      verify(mockApi.removeAppExtData('k')).called(1);
      verify(mockApi.clearAppExtData()).called(1);
    });

    test('access control list calls api', () async {
      await PrebidTargeting.addBidderToAccessControlList('appnexus');
      await PrebidTargeting.removeBidderFromAccessControlList('appnexus');
      await PrebidTargeting.clearAccessControlList();
      verify(mockApi.addBidderToAccessControlList('appnexus')).called(1);
      verify(mockApi.removeBidderFromAccessControlList('appnexus')).called(1);
      verify(mockApi.clearAccessControlList()).called(1);
    });
  });

  group('PrebidTargeting app information', () {
    test('store URL and domain call api', () async {
      await PrebidTargeting.setStoreUrl('https://store');
      await PrebidTargeting.setDomain('example.com');
      await PrebidTargeting.setPublisherName(null);
      verify(mockApi.setStoreUrl('https://store')).called(1);
      verify(mockApi.setDomain('example.com')).called(1);
      verify(mockApi.setPublisherName(null)).called(1);
    });

    test('nullable setters forward null', () async {
      await PrebidTargeting.setSourceApp(null);
      await PrebidTargeting.setItunesId(null);
      await PrebidTargeting.setOmidPartnerName(null);
      await PrebidTargeting.setOmidPartnerVersion(null);
      await PrebidTargeting.setLocationPrecision(null);
      verify(mockApi.setSourceApp(null)).called(1);
      verify(mockApi.setItunesId(null)).called(1);
      verify(mockApi.setOmidPartnerName(null)).called(1);
      verify(mockApi.setOmidPartnerVersion(null)).called(1);
      verify(mockApi.setLocationPrecision(null)).called(1);
    });

    test('setAppName forwards the name and null', () async {
      await PrebidTargeting.setAppName('天気');
      await PrebidTargeting.setAppName(null);
      verify(mockApi.setAppName('天気')).called(1);
      verify(mockApi.setAppName(null)).called(1);
    });
  });

  group('user ext', () {
    test('is sent to the platform as JSON', () async {
      await PrebidTargeting.setUserExt({
        'consented_providers': [1, 2],
        'segment': 'a',
      });
      verify(
        mockApi.setUserExt('{"consented_providers":[1,2],"segment":"a"}'),
      ).called(1);
    });

    test('null clears it', () async {
      await PrebidTargeting.setUserExt(null);
      verify(mockApi.setUserExt(null)).called(1);
    });

    test('is read back as a map, null when empty', () async {
      when(
        mockApi.getUserExt(),
      ).thenAnswer((_) async => '{"data":{"k":["v"]},"segment":"a"}');
      expect(await PrebidTargeting.getUserExt(), {
        'data': {
          'k': ['v'],
        },
        'segment': 'a',
      });
      when(mockApi.getUserExt()).thenAnswer((_) async => null);
      expect(await PrebidTargeting.getUserExt(), isNull);
    });
  });
}
