import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';
import 'package:prebid_mobile_sdk/src/generated/prebid_api.g.dart';

import 'mock_host_api.mocks.dart';

void main() {
  late MockPrebidMobileHostApi mockApi;

  setUp(() {
    mockApi = MockPrebidMobileHostApi();
    PrebidMobile.api = mockApi;
  });

  group('PrebidMobile Configuration API', () {
    test('initializeSdk calls api with correct args', () async {
      when(mockApi.initializeSdk(any, any)).thenAnswer(
        (_) async =>
            InitializationResult(status: InitializationStatus.succeeded.name),
      );

      await PrebidMobile.initializeSdk(
        prebidServerUrl: 'https://test.com',
        accountId: 'account-123',
      );

      verify(
        mockApi.initializeSdk('https://test.com', 'account-123'),
      ).called(1);
    });

    test('setTimeoutMillis calls api', () async {
      await PrebidMobile.setTimeoutMillis(5000);
      verify(mockApi.setTimeoutMillis(5000)).called(1);
    });

    test('setShareGeoLocation calls api', () async {
      await PrebidMobile.setShareGeoLocation(true);
      verify(mockApi.setShareGeoLocation(true)).called(1);
    });

    test('setPbsDebug calls api', () async {
      await PrebidMobile.setPbsDebug(true);
      verify(mockApi.setPbsDebug(true)).called(1);
    });

    test('setCustomHeaders calls api', () async {
      final headers = {'X-Test': 'Value'};
      await PrebidMobile.setCustomHeaders(headers);
      verify(mockApi.setCustomHeaders(headers)).called(1);
    });

    test('setStoredAuctionResponse calls api', () async {
      await PrebidMobile.setStoredAuctionResponse('mock-id');
      verify(mockApi.setStoredAuctionResponse('mock-id')).called(1);
    });

    test('clearStoredAuctionResponse calls api', () async {
      await PrebidMobile.clearStoredAuctionResponse();
      verify(mockApi.clearStoredAuctionResponse()).called(1);
    });

    test('addStoredBidResponse calls api', () async {
      await PrebidMobile.addStoredBidResponse('rubicon', 'resp-123');
      verify(mockApi.addStoredBidResponse('rubicon', 'resp-123')).called(1);
    });

    test('clearStoredBidResponses calls api', () async {
      await PrebidMobile.clearStoredBidResponses();
      verify(mockApi.clearStoredBidResponses()).called(1);
    });

    test('setLogLevel calls api with correct values', () async {
      await PrebidMobile.setLogLevel(PrebidLogLevel.debug);
      verify(
        mockApi.setLogLevel(0),
      ).called(1); // debug = 0 in Kotlin enum mapping

      await PrebidMobile.setLogLevel(PrebidLogLevel.error);
      verify(mockApi.setLogLevel(4)).called(1); // error = 4
    });

    test('setCreativeFactoryTimeout calls api', () async {
      await PrebidMobile.setCreativeFactoryTimeout(7000);
      verify(mockApi.setCreativeFactoryTimeout(7000)).called(1);
    });

    test('setCreativeFactoryTimeoutPreRenderContent calls api', () async {
      await PrebidMobile.setCreativeFactoryTimeoutPreRenderContent(20000);
      verify(
        mockApi.setCreativeFactoryTimeoutPreRenderContent(20000),
      ).called(1);
    });

    test('setCustomStatusEndpoint calls api', () async {
      await PrebidMobile.setCustomStatusEndpoint('https://status.omg.com');
      verify(
        mockApi.setCustomStatusEndpoint('https://status.omg.com'),
      ).called(1);
    });
  });

  group('External User IDs', () {
    test('setExternalUserIds converts and calls api', () async {
      await PrebidMobile.setExternalUserIds([
        const ExternalUserId(
          source: 'uidapi.com',
          identifier: 'uid2-abc-123',
          atype: 3,
        ),
        const ExternalUserId(
          source: 'sharedid.org',
          identifier: 'shared-xyz',
          atype: 1,
        ),
      ]);

      verify(mockApi.setExternalUserIds(any)).called(1);
    });

    test('getExternalUserIds returns mapped list', () async {
      when(mockApi.getExternalUserIds()).thenAnswer(
        (_) async => [
          ExternalUserIdData(
            source: 'uidapi.com',
            identifier: 'uid2-abc-123',
            atype: 3,
          ),
        ],
      );

      final result = await PrebidMobile.getExternalUserIds();
      expect(result, hasLength(1));
      expect(result[0].source, 'uidapi.com');
      expect(result[0].identifier, 'uid2-abc-123');
      expect(result[0].atype, 3);
    });

    test('clearExternalUserIds calls api', () async {
      await PrebidMobile.clearExternalUserIds();
      verify(mockApi.clearExternalUserIds()).called(1);
    });
  });

  group('SDK Version', () {
    test('getSdkVersion returns version string', () async {
      when(mockApi.getSdkVersion()).thenAnswer((_) async => '3.3.0');

      final version = await PrebidMobile.getSdkVersion();
      expect(version, '3.3.0');
      verify(mockApi.getSdkVersion()).called(1);
    });
  });
}
