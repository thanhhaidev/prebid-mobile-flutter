import 'package:flutter/services.dart';
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
      when(mockApi.initializeSdk(any, any, any)).thenAnswer(
        (_) async => InitializationResult(
          status: PrebidInitializationStatus.succeeded.name,
        ),
      );

      await PrebidMobile.initializeSdk(
        prebidServerUrl: 'https://test.com',
        accountId: 'account-123',
      );

      verify(
        mockApi.initializeSdk('https://test.com', 'account-123', null),
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

  group('Runtime server settings', () {
    test('account id is set and read back', () async {
      when(
        mockApi.getPrebidServerAccountId(),
      ).thenAnswer((_) async => 'acct-2');

      await PrebidMobile.setPrebidServerAccountId('acct-2');

      verify(mockApi.setPrebidServerAccountId('acct-2')).called(1);
      expect(await PrebidMobile.getPrebidServerAccountId(), 'acct-2');
    });

    test('server url is set and read back, null when unset', () async {
      const url = 'https://pbs.example.com/openrtb2/auction';
      when(mockApi.getPrebidServerUrl()).thenAnswer((_) async => null);
      expect(await PrebidMobile.getPrebidServerUrl(), isNull);

      await PrebidMobile.setPrebidServerUrl(url);
      when(mockApi.getPrebidServerUrl()).thenAnswer((_) async => url);

      verify(mockApi.setPrebidServerUrl(url)).called(1);
      expect(await PrebidMobile.getPrebidServerUrl(), url);
    });

    test('an invalid server url surfaces the platform error', () async {
      when(
        mockApi.setPrebidServerUrl(any),
      ).thenThrow(PlatformException(code: 'prebidServerURLInvalid'));

      expect(
        () => PrebidMobile.setPrebidServerUrl('not a url'),
        throwsA(isA<PlatformException>()),
      );
    });

    test('use cache for reporting is set and read back', () async {
      when(
        mockApi.getUseCacheForReportingWithRenderingApi(),
      ).thenAnswer((_) async => true);

      await PrebidMobile.setUseCacheForReportingWithRenderingApi(true);

      verify(mockApi.setUseCacheForReportingWithRenderingApi(true)).called(1);
      expect(
        await PrebidMobile.getUseCacheForReportingWithRenderingApi(),
        true,
      );
    });

    test('creative factory timeouts are read in milliseconds', () async {
      when(mockApi.getCreativeFactoryTimeout()).thenAnswer((_) async => 6000);
      when(
        mockApi.getCreativeFactoryTimeoutPreRenderContent(),
      ).thenAnswer((_) async => 30000);

      expect(await PrebidMobile.getCreativeFactoryTimeout(), 6000);
      expect(
        await PrebidMobile.getCreativeFactoryTimeoutPreRenderContent(),
        30000,
      );
    });

    test('getOmsdkVersion returns the native value', () async {
      when(mockApi.getOmsdkVersion()).thenAnswer((_) async => '1.4.1');
      expect(await PrebidMobile.getOmsdkVersion(), '1.4.1');
      verify(mockApi.getOmsdkVersion()).called(1);
    });
  });

  group('PrebidMobile 3.4 settings', () {
    test('filter / eids placement / targeting flags call api', () async {
      await PrebidMobile.setFilterOutUncachedBids(true);
      await PrebidMobile.setEidsPlacement(PrebidEidsPlacement.openRtb26);
      await PrebidMobile.setIncludeWinners(true);
      await PrebidMobile.setIncludeBidderKeys(false);
      await PrebidMobile.setShouldAssignNativeAssetId(true);

      verify(mockApi.setFilterOutUncachedBids(true)).called(1);
      verify(mockApi.setEidsPlacement('openRtb26')).called(1);
      verify(mockApi.setIncludeWinners(true)).called(1);
      verify(mockApi.setIncludeBidderKeys(false)).called(1);
      verify(mockApi.setShouldAssignNativeAssetId(true)).called(1);
    });

    test('external user ids carry OpenRTB 2.6 fields both ways', () async {
      await PrebidMobile.setExternalUserIds([
        const ExternalUserId(
          source: 'uidapi.com',
          identifier: 'uid2',
          atype: 3,
          inserter: 'inserter.com',
          matcher: 'matcher.com',
          mm: 3,
        ),
      ]);
      final sent =
          verify(mockApi.setExternalUserIds(captureAny)).captured.single
              as List<ExternalUserIdData>;
      expect(sent.single.inserter, 'inserter.com');
      expect(sent.single.matcher, 'matcher.com');
      expect(sent.single.mm, 3);

      when(mockApi.getExternalUserIds()).thenAnswer(
        (_) async => [
          ExternalUserIdData(
            source: 'uidapi.com',
            identifier: 'uid2',
            inserter: 'inserter.com',
            matcher: 'matcher.com',
            mm: 3,
          ),
        ],
      );
      final ids = await PrebidMobile.getExternalUserIds();
      expect(ids.single.inserter, 'inserter.com');
      expect(ids.single.matcher, 'matcher.com');
      expect(ids.single.mm, 3);
    });
  });

  group('PrebidMobile SharedID, settings id and bid events', () {
    test('isSdkInitialized follows the init status', () async {
      when(mockApi.initializeSdk(any, any, any)).thenAnswer(
        (_) async => InitializationResult(status: 'failed', error: 'x'),
      );
      await PrebidMobile.initializeSdk(prebidServerUrl: 'u', accountId: 'a');
      expect(PrebidMobile.isSdkInitialized, isFalse);

      when(mockApi.initializeSdk(any, any, any)).thenAnswer(
        (_) async => InitializationResult(status: 'serverStatusWarning'),
      );
      await PrebidMobile.initializeSdk(prebidServerUrl: 'u', accountId: 'a');
      expect(PrebidMobile.isSdkInitialized, isTrue);
    });

    test('SharedID calls api and maps the id', () async {
      when(mockApi.getSharedId()).thenAnswer(
        (_) async => ExternalUserIdData(
          source: 'pubcid.org',
          identifier: 'abc',
          atype: 1,
        ),
      );
      await PrebidMobile.setSendSharedId(true);
      final id = await PrebidMobile.getSharedId();
      await PrebidMobile.resetSharedId();

      verify(mockApi.setSendSharedId(true)).called(1);
      verify(mockApi.resetSharedId()).called(1);
      expect(id?.source, 'pubcid.org');
      expect(id?.identifier, 'abc');
      expect(id?.atype, 1);
    });

    test('setAuctionSettingsId calls api', () async {
      await PrebidMobile.setAuctionSettingsId('settings-1');
      verify(mockApi.setAuctionSettingsId('settings-1')).called(1);
    });

    test('event listener toggles the delegate and receives bids', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final received = <(String?, String?)>[];
      await PrebidMobile.setEventListener(
        (req, res) => received.add((req, res)),
      );
      verify(mockApi.setEventDelegateEnabled(true)).called(1);

      const channel =
          'dev.flutter.pigeon.prebid_mobile_sdk.PrebidEventFlutterApi.onBidResponse';
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel,
            const StandardMessageCodec().encodeMessage(<Object?>[
              '{"id":"req"}',
              '{"id":"res"}',
            ]),
            (_) {},
          );
      expect(received, [('{"id":"req"}', '{"id":"res"}')]);

      await PrebidMobile.setEventListener(null);
      verify(mockApi.setEventDelegateEnabled(false)).called(1);
    });
  });
}
