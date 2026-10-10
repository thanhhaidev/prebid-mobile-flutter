import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

import 'mock_host_api.mocks.dart';

void main() {
  late MockTargetingHostApi api;

  setUp(() {
    api = MockTargetingHostApi();
    PrebidTargeting.api = api;
  });

  group('each setting reaches the platform', () {
    final settings = <String, (Future<void> Function(), void Function())>{
      'setSubjectToCOPPA': (
        () => PrebidTargeting.setSubjectToCOPPA(true),
        () => api.setSubjectToCOPPA(true),
      ),
      'setSubjectToCOPPA(null)': (
        () => PrebidTargeting.setSubjectToCOPPA(null),
        () => api.setSubjectToCOPPA(null),
      ),
      'setSubjectToGDPR': (
        () => PrebidTargeting.setSubjectToGDPR(false),
        () => api.setSubjectToGDPR(false),
      ),
      'setSubjectToGDPR(null)': (
        () => PrebidTargeting.setSubjectToGDPR(null),
        () => api.setSubjectToGDPR(null),
      ),
      'setGDPRConsentString': (
        () => PrebidTargeting.setGDPRConsentString('tcf'),
        () => api.setGDPRConsentString('tcf'),
      ),
      'setGDPRConsentString(null)': (
        () => PrebidTargeting.setGDPRConsentString(null),
        () => api.setGDPRConsentString(null),
      ),
      'setPurposeConsents': (
        () => PrebidTargeting.setPurposeConsents('101'),
        () => api.setPurposeConsents('101'),
      ),
      'setPurposeConsents(null)': (
        () => PrebidTargeting.setPurposeConsents(null),
        () => api.setPurposeConsents(null),
      ),
      'setUSPrivacyString': (
        () => PrebidTargeting.setUSPrivacyString('1YNN'),
        () => api.setUSPrivacyString('1YNN'),
      ),
      'setUSPrivacyString(null)': (
        () => PrebidTargeting.setUSPrivacyString(null),
        () => api.setUSPrivacyString(null),
      ),
      'addUserKeyword': (
        () => PrebidTargeting.addUserKeyword('sports'),
        () => api.addUserKeyword('sports'),
      ),
      'removeUserKeyword': (
        () => PrebidTargeting.removeUserKeyword('sports'),
        () => api.removeUserKeyword('sports'),
      ),
      'clearUserKeywords': (
        PrebidTargeting.clearUserKeywords,
        () => api.clearUserKeywords(),
      ),
      'addAppKeyword': (
        () => PrebidTargeting.addAppKeyword('news'),
        () => api.addAppKeyword('news'),
      ),
      'removeAppKeyword': (
        () => PrebidTargeting.removeAppKeyword('news'),
        () => api.removeAppKeyword('news'),
      ),
      'clearAppKeywords': (
        PrebidTargeting.clearAppKeywords,
        () => api.clearAppKeywords(),
      ),
      'addAppExtData': (
        () => PrebidTargeting.addAppExtData(key: 'segment', value: 'premium'),
        () => api.addAppExtData('segment', 'premium'),
      ),
      'removeAppExtData': (
        () => PrebidTargeting.removeAppExtData('segment'),
        () => api.removeAppExtData('segment'),
      ),
      'clearAppExtData': (
        PrebidTargeting.clearAppExtData,
        () => api.clearAppExtData(),
      ),
      'addUserExtData': (
        () => PrebidTargeting.addUserExtData(key: 'segment', value: 'premium'),
        () => api.addUserExtData('segment', 'premium'),
      ),
      'removeUserExtData': (
        () => PrebidTargeting.removeUserExtData('segment'),
        () => api.removeUserExtData('segment'),
      ),
      'clearUserExtData': (
        PrebidTargeting.clearUserExtData,
        () => api.clearUserExtData(),
      ),
      'addBidderToAccessControlList': (
        () => PrebidTargeting.addBidderToAccessControlList('appnexus'),
        () => api.addBidderToAccessControlList('appnexus'),
      ),
      'removeBidderFromAccessControlList': (
        () => PrebidTargeting.removeBidderFromAccessControlList('appnexus'),
        () => api.removeBidderFromAccessControlList('appnexus'),
      ),
      'clearAccessControlList': (
        PrebidTargeting.clearAccessControlList,
        () => api.clearAccessControlList(),
      ),
      'setPublisherName': (
        () => PrebidTargeting.setPublisherName('CoolApp'),
        () => api.setPublisherName('CoolApp'),
      ),
      'setStoreUrl': (
        () => PrebidTargeting.setStoreUrl('https://store'),
        () => api.setStoreUrl('https://store'),
      ),
      'setDomain': (
        () => PrebidTargeting.setDomain('example.com'),
        () => api.setDomain('example.com'),
      ),
      'setAppName': (
        () => PrebidTargeting.setAppName('天気'),
        () => api.setAppName('天気'),
      ),
      'setAppName(null)': (
        () => PrebidTargeting.setAppName(null),
        () => api.setAppName(null),
      ),
      'setSourceApp': (
        () => PrebidTargeting.setSourceApp('123456789'),
        () => api.setSourceApp('123456789'),
      ),
      'setItunesId': (
        () => PrebidTargeting.setItunesId('123456789'),
        () => api.setItunesId('123456789'),
      ),
      'setBundleName': (
        () => PrebidTargeting.setBundleName('com.prod'),
        () => api.setBundleName('com.prod'),
      ),
      'setOmidPartnerName': (
        () => PrebidTargeting.setOmidPartnerName('Prebid'),
        () => api.setOmidPartnerName('Prebid'),
      ),
      'setOmidPartnerVersion': (
        () => PrebidTargeting.setOmidPartnerVersion('1.0'),
        () => api.setOmidPartnerVersion('1.0'),
      ),
      'setUserLatLng': (
        () => PrebidTargeting.setUserLatLng(10.5, 106.7),
        () => api.setUserLatLng(10.5, 106.7),
      ),
      'clearUserLatLng': (
        PrebidTargeting.clearUserLatLng,
        () => api.clearUserLatLng(),
      ),
      'setLocationPrecision': (
        () => PrebidTargeting.setLocationPrecision(2),
        () => api.setLocationPrecision(2),
      ),
      'setLocationPrecision(null)': (
        () => PrebidTargeting.setLocationPrecision(null),
        () => api.setLocationPrecision(null),
      ),
    };
    for (final MapEntry(key: name, value: (set, expected))
        in settings.entries) {
      test(name, () async {
        await set();
        verify(expected()).called(1);
      });
    }

    test('sets of keywords and values travel as lists', () async {
      await PrebidTargeting.addUserKeywords({'a', 'b'});
      await PrebidTargeting.addAppKeywords({'x', 'y'});
      await PrebidTargeting.updateAppExtData(key: 'k', value: {'v1', 'v2'});
      await PrebidTargeting.updateUserExtData(
        key: 'interests',
        value: {'sports', 'tech'},
      );
      verify(api.addUserKeywords(['a', 'b'])).called(1);
      verify(api.addAppKeywords(['x', 'y'])).called(1);
      verify(api.updateAppExtData('k', ['v1', 'v2'])).called(1);
      verify(api.updateUserExtData('interests', ['sports', 'tech'])).called(1);
    });

    test('user ext travels as JSON, null clears it', () async {
      await PrebidTargeting.setUserExt({
        'consented_providers': [1, 2],
        'segment': 'a',
      });
      await PrebidTargeting.setUserExt(null);
      verify(
        api.setUserExt('{"consented_providers":[1,2],"segment":"a"}'),
      ).called(1);
      verify(api.setUserExt(null)).called(1);
    });
  });

  group('each getter returns the platform value', () {
    final getters =
        <String, (void Function(), Future<Object?> Function(), Object?)>{
          'getSubjectToCOPPA': (
            () => when(api.getSubjectToCOPPA()).thenAnswer((_) async => true),
            PrebidTargeting.getSubjectToCOPPA,
            true,
          ),
          'getSubjectToGDPR, unset': (
            () => when(api.getSubjectToGDPR()).thenAnswer((_) async => null),
            PrebidTargeting.getSubjectToGDPR,
            null,
          ),
          'getGDPRConsentString': (
            () =>
                when(api.getGDPRConsentString()).thenAnswer((_) async => 'tcf'),
            PrebidTargeting.getGDPRConsentString,
            'tcf',
          ),
          'getPurposeConsents': (
            () => when(api.getPurposeConsents()).thenAnswer((_) async => '101'),
            PrebidTargeting.getPurposeConsents,
            '101',
          ),
          'getPurposeConsent(0)': (
            () => when(api.getPurposeConsent(0)).thenAnswer((_) async => true),
            () => PrebidTargeting.getPurposeConsent(0),
            true,
          ),
          'getDeviceAccessConsent': (
            () => when(
              api.getDeviceAccessConsent(),
            ).thenAnswer((_) async => false),
            PrebidTargeting.getDeviceAccessConsent,
            false,
          ),
          'isAllowedAccessDeviceData': (
            () => when(
              api.isAllowedAccessDeviceData(),
            ).thenAnswer((_) async => true),
            PrebidTargeting.isAllowedAccessDeviceData,
            true,
          ),
          'getUSPrivacyString': (
            () =>
                when(api.getUSPrivacyString()).thenAnswer((_) async => '1YNN'),
            PrebidTargeting.getUSPrivacyString,
            '1YNN',
          ),
          'getUserKeywords': (
            () => when(api.getUserKeywords()).thenAnswer((_) async => ['a']),
            PrebidTargeting.getUserKeywords,
            ['a'],
          ),
          'getAppKeywords': (
            () => when(api.getAppKeywords()).thenAnswer((_) async => ['news']),
            PrebidTargeting.getAppKeywords,
            ['news'],
          ),
          'getAppExtData': (
            () => when(api.getAppExtData()).thenAnswer(
              (_) async => {
                'k': ['v'],
              },
            ),
            PrebidTargeting.getAppExtData,
            {
              'k': ['v'],
            },
          ),
          'getAccessControlList': (
            () => when(
              api.getAccessControlList(),
            ).thenAnswer((_) async => ['appnexus']),
            PrebidTargeting.getAccessControlList,
            ['appnexus'],
          ),
          'getGlobalOrtbConfig': (
            () => when(api.getGlobalOrtbConfig()).thenAnswer((_) async => '{}'),
            PrebidTargeting.getGlobalOrtbConfig,
            '{}',
          ),
          'getPublisherName': (
            () =>
                when(api.getPublisherName()).thenAnswer((_) async => 'CoolApp'),
            PrebidTargeting.getPublisherName,
            'CoolApp',
          ),
          'getStoreUrl': (
            () => when(
              api.getStoreUrl(),
            ).thenAnswer((_) async => 'https://store'),
            PrebidTargeting.getStoreUrl,
            'https://store',
          ),
          'getDomain': (
            () => when(api.getDomain()).thenAnswer((_) async => 'example.com'),
            PrebidTargeting.getDomain,
            'example.com',
          ),
          'getSourceApp': (
            () => when(api.getSourceApp()).thenAnswer((_) async => '123'),
            PrebidTargeting.getSourceApp,
            '123',
          ),
          'getItunesId': (
            () => when(api.getItunesId()).thenAnswer((_) async => '456'),
            PrebidTargeting.getItunesId,
            '456',
          ),
          'getBundleName': (
            () => when(api.getBundleName()).thenAnswer((_) async => 'com.prod'),
            PrebidTargeting.getBundleName,
            'com.prod',
          ),
          'getOmidPartnerName': (
            () => when(
              api.getOmidPartnerName(),
            ).thenAnswer((_) async => 'Prebid'),
            PrebidTargeting.getOmidPartnerName,
            'Prebid',
          ),
          'getOmidPartnerVersion': (
            () => when(
              api.getOmidPartnerVersion(),
            ).thenAnswer((_) async => '1.0'),
            PrebidTargeting.getOmidPartnerVersion,
            '1.0',
          ),
          'getSendSharedId': (
            () => when(api.getSendSharedId()).thenAnswer((_) async => true),
            PrebidTargeting.getSendSharedId,
            true,
          ),
          'getLocationPrecision': (
            () => when(api.getLocationPrecision()).thenAnswer((_) async => 2),
            PrebidTargeting.getLocationPrecision,
            2,
          ),
        };
    for (final MapEntry(key: name, value: (stub, get, expected))
        in getters.entries) {
      test(name, () async {
        stub();
        expect(await get(), expected);
      });
    }

    test('the user location is a (latitude, longitude) pair', () async {
      when(api.getUserLatLng()).thenAnswer((_) async => [1.5, 2.5]);
      expect(await PrebidTargeting.getUserLatLng(), (1.5, 2.5));
      when(api.getUserLatLng()).thenAnswer((_) async => null);
      expect(await PrebidTargeting.getUserLatLng(), isNull);
    });

    test('user ext is read back as a map, null when empty', () async {
      when(
        api.getUserExt(),
      ).thenAnswer((_) async => '{"data":{"k":["v"]},"segment":"a"}');
      expect(await PrebidTargeting.getUserExt(), {
        'data': {
          'k': ['v'],
        },
        'segment': 'a',
      });
      when(api.getUserExt()).thenAnswer((_) async => null);
      expect(await PrebidTargeting.getUserExt(), isNull);
    });
  });

  group('the global OpenRTB config carries the plugin record', () {
    const record =
        '"prebid":{"wrapper":{"name":"prebid_mobile_sdk","version":"1.0.0"}}';

    for (final (name, set, sent) in [
      (
        'added to a config',
        '{"bcat":["IAB1"]}',
        '{"bcat":["IAB1"],"app":{"ext":{$record}}}',
      ),
      ('the whole config when cleared', null, '{"app":{"ext":{$record}}}'),
      (
        'merged into the app\'s own app.ext',
        '{"app":{"name":"n","ext":{"data":{"k":"v"}}}}',
        '{"app":{"name":"n","ext":{"data":{"k":"v"},$record}}}',
      ),
      ('not added to invalid JSON', '{bcat', '{bcat'),
      ('not added to a JSON array', '[1]', '[1]'),
    ]) {
      test(name, () async {
        await PrebidTargeting.setGlobalOrtbConfig(set);
        verify(api.setGlobalOrtbConfig(sent)).called(1);
      });
    }

    for (final (name, stored, read) in [
      (
        'left out when read back',
        '{"bcat":["IAB1"],"app":{"ext":{$record}}}',
        '{"bcat":["IAB1"]}',
      ),
      ('null when it was the only content', '{"app":{"ext":{$record}}}', null),
      (
        'removed without the app\'s other app fields',
        '{"app":{"name":"n","ext":{"prebid":{"source":"s","wrapper":{}}}}}',
        '{"app":{"name":"n","ext":{"prebid":{"source":"s"}}}}',
      ),
      (
        'a config without it, unchanged',
        '{ "bcat": ["IAB1"] }',
        '{ "bcat": ["IAB1"] }',
      ),
      ('nothing stored', null, null),
    ]) {
      test(name, () async {
        when(api.getGlobalOrtbConfig()).thenAnswer((_) async => stored);
        expect(await PrebidTargeting.getGlobalOrtbConfig(), read);
      });
    }

    test('names the version in pubspec.yaml', () async {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(
        r'^version: (\S+)$',
        multiLine: true,
      ).firstMatch(pubspec)!.group(1);
      await PrebidTargeting.setGlobalOrtbConfig(null);
      final sent =
          verify(api.setGlobalOrtbConfig(captureAny)).captured.single as String;
      expect(sent, contains('"version":"$version"'));
    });
  });
}
